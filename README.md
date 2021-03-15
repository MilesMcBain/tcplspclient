
<!-- README.md is generated from README.Rmd. Please edit that file -->

# tcplspclient

<!-- badges: start -->

<!-- badges: end -->

A TCP client for corresponding with R’s language server enabling
interactive debugging.

## Installation

``` r
pak::pkg_install("milesmcbain/tcplspclient")
```

## Usage

In R session 1 (client):

1.  Start the client. (It’s technically the server. Good one Microsoft.)

<!-- end list -->

``` r
library(tcplspclient)
client <- TCPLanguageClient$new(host = "localhost", port = 8888)
```

In R session 2 (server):

0.  `devtools::load_all()`
1.  Add `browser()` statements or use `debugonce()`/`debug()` etc to
    `languageserver` functions.
2.  Connect the language server to the client:

<!-- end list -->

``` r
run(port = 8888)
```

In R session 1 (client)

1.  Do handshake.

<!-- end list -->

``` r
# TCP client connected to localhost:8888
server_capabilities <- client$handshake()

server_capabilities
# $textDocumentSync
# $textDocumentSync$openClose
# [1] TRUE

# $textDocumentSync$change
# [1] 1

# $textDocumentSync$willSave
# [1] FALSE

# ...
```

2.  Send messages to trigger server actions to debug in session 2.

<!-- end list -->

  - note see [this
    file](https://github.com/REditorSupport/languageserver/blob/master/tests/testthat/helper-utils.R)
    for protocol wrapper functions.

<!-- end list -->

``` r
doc_path <- "~/code/r/blogdown_test/content/post/test2.R"

client$send_notification(
        method = "textDocument/didSave",
        params  = list(textDocument = list(
          uri = languageserver:::path_to_uri(doc_path)), 
          text = paste0(stringi::stri_read_lines(doc_path), collapse = "\n")
        )
)

response <- client$send_message(
        method = "textDocument/documentSymbol",
        params = list(
            textDocument = list(uri = 
                languageserver:::path_to_uri("~/code/r/blogdown_test/content/post/test2.R"))
        )
    )
```

Now debug interactively in R session 1. Eventually get the response you
expected:

``` r
response

# response
# [[1]]
# [[1]]$name
# [1] "f"

# [[1]]$kind
# [1] 12

# [[1]]$location
# [[1]]$location$uri
# [1] "file:///home/miles/code/r/blogdown_test/content/post/test2.R"

# [[1]]$location$range
# [[1]]$location$range$start
# [[1]]$location$range$start$line
# [1] 0

# [[1]]$location$range$start$character
# [1] 0
```

## Licenses

Code in this project is substantially copied from the
[{languageserver}](https://github.com/REditorSupport/languageserver).
Code files carry approriate licenses and attribution in header comments.
