cc_library(
    name = "hello-greet",
    srcs = ["hello-greet.cc"],
    deps = ["//:headers"],
)

cc_binary(
    name = "hello-world",
    srcs = ["hello-world.cc"],
    deps = [
        ":hello-greet",
        "//:headers",
        "//src/main/c++/time:hello-time",
    ],
)
