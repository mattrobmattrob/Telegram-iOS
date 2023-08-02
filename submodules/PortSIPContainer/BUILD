load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

swift_library(
    name = "PortSIPContainer",
    module_name = "PortSIPContainer",
    srcs = ["PortSIPContainer.swift"],
    deps = ["//third-party/PortSIP:PortSIPVoIPSDK"],
    visibility = [
        "//visibility:public",
    ],
)
