# README

Mac平台，识别图片中按钮坐标位置

```
swiftc -target arm64-apple-macos11 ocrtext_coords.swift -o ocrtext_coords-arm64

swiftc -target x86_64-apple-macos10.15 ocrtext_coords.swift -o ocrtext_coords-x86_64

lipo -create ocrtext_coords-arm64 ocrtext_coords-x86_64 -output ocrtext_coords
```