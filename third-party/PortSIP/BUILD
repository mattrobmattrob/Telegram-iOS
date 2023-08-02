load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_framework_import",
    "apple_static_xcframework_import",
)

apple_static_framework_import(
    name = "PortSIPVoIPSDK",
    framework_imports = glob(
        ["PortSIPVoIPSDK.framework/**"],
    ),
    sdk_dylibs = [
        "resolv",
    ],
    sdk_frameworks = [
        "AudioToolbox",
        "AVFoundation",
        "CoreGraphics",
        "VideoToolbox",
        "UIKit",
        "CoreMedia",
        "CoreVideo",
        "OpenGLES",
        "CoreGraphics",
        "QuartzCore",
    ],
    weak_sdk_frameworks = [
        "Network",
        "Metal",
        "MetalKit",
        "GLKit",
    ],
    visibility = ["//visibility:public"],
)
