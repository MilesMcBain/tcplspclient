# Code in this file is subtantially copied from the {languageserver} package.
# See: https://github.com/REditorSupport/languageserver
# It has an license MIT, reproduced below:

# Copyright (c) 2018 Randy Lai

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

#' @export
TCPLanguageClient <- R6::R6Class("TCPLanguageClient",
    inherit = languageserver:::LanguageBase,
    private = list(
        read_char_buf = raw(0)
    ),
    public = list(
        connection = NULL,
        rootUri = NULL,
        ClientCapabilities = NULL,
        ServerCapabilities = NULL,
        diagnostics = NULL,

        initialize = function(host = "localhost", port = NULL) {
            if (is.null(port)) stop("port required to connect over TCP")
            self$connection <- socketConnection(host = host, port = port, open = "r+b", server = TRUE)
            message("TCP client connected to ", paste0(host,":",port))
            super$initialize()
        },

        finalize = function() {
            if (!is.null(self$connection)) {
                close(self$connection)
                self$connection <- NULL
            }
            super$finalize()
        },

        check_connection = function() {
            if (!is.null(self$connection) && !isOpen(self$connection))
                stop("Server is dead.")
        },

        write_text = function(text) {
            self$check_connection()
            writeLines(text, self$connection)
        },

        read_output_lines = function(timeout = 5) {
            self$check_connection()
            if (socketSelect(list(self$connection), timeout = timeout)) {
                    readLines(self$connection, encoding = "UTF-8")
                } else {
                    character(0)
                }
        },

        read_line = function() {
            self$check_connection()
            if (socketSelect(list(self$connection), timeout = 0)) {
                    readLines(self$connection, n = 1, encoding = "UTF-8")
                } else {
                    character(0)
                }
        },

        read_char = function(n) {
            self$check_connection()
            out <- readChar(self$connection, n, useBytes = TRUE)
            Encoding(out) <- "UTF-8"
            out
        },

        welcome = function() {
            self$deliver(
                self$request(
                    "initialize",
                    list(
                        rootUri = self$rootUri,
                        capabilities = self$ClientCapabilities
                    )
                ),
                callback = function(self, result) {
                    self$ServerCapabilities <- result$capabilities
                }
            )
        },

        start = function(working_dir = getwd(), capabilities = NULL) {
            self$rootUri <- languageserver:::path_to_uri(working_dir)
            self$ClientCapabilities <- capabilities
            self$welcome()
        },

        run = function() {
            # placeholder
        },

        handshake = function() {
            self$start()
            data <- self$fetch(blocking = TRUE)
            server_capabilities <- self$handle_raw(data)
            server_capabilities
        },

        send_message = function(method, params, timeout, allow_error = FALSE,
                                retry = TRUE, retry_when = function(result) length(result) == 0) {
            if (missing(timeout)) {
                if (Sys.getenv("R_COVR", "") == "true") {
                    # we give more time to covr
                    timeout <- 30
                } else {
                    timeout <- 10
                }
            }
            storage <- new.env(parent = .GlobalEnv)
            cb <- function(self, result, error = NULL) {
                if (is.null(error)) {
                    storage$done <- TRUE
                    storage$result <- result
                } else if (allow_error) {
                    storage$done <- TRUE
                    storage$result <- error
                }
            }

            start_time <- Sys.time()
            remaining <- timeout
            self$deliver(self$request(method, params), callback = cb)
            if (method == "shutdown") {
                # do not expect the server returns anything
                return(NULL)
            }
            while (!isTRUE(storage$done)) {
                if (remaining < 0) {
                    stop("timeout when obtaining response")
                    return(NULL)
                }
                data <- self$fetch(blocking = TRUE, timeout = remaining)
                if (!is.null(data)) self$handle_raw(data)
                remaining <- (start_time + timeout) - Sys.time()
            }
            result <- storage$result
            if (retry && retry_when(result)) {
                remaining <- (start_time + timeout) - Sys.time()
                if (remaining < 0) {
                    stop("timeout when obtaining desired response")
                    return(NULL)
                }
                Sys.sleep(0.2)
                return(Recall(method, params, remaining, allow_error, retry, retry_when))
            }
            return(result)
        },

        send_notification = function(method, params = NULL) {
            invisible(self$deliver(languageserver:::Notification$new(method, params)))
        }

    )
)


TCPLanguageClient$set("public", "register_handlers", function() {
    self$request_handlers <- list()
    self$notification_handlers <- list()
})
