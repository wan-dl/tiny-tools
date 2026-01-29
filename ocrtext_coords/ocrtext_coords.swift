#!/usr/bin/env swift

import Foundation
import Vision
import AppKit

struct TextLocation {
    let text: String
    let boundingBox: CGRect
    let confidence: Float
}

func findTextLocation(in imagePath: String, searchText: String, languages: [String] = ["zh-Hans", "zh-Hant", "en-US"]) -> [TextLocation] {
    guard let image = NSImage(contentsOfFile: imagePath),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return []
    }
    
    let imageWidth = CGFloat(cgImage.width)
    let imageHeight = CGFloat(cgImage.height)
    
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = languages
    
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    var results: [TextLocation] = []
    
    do {
        try handler.perform([request])
        
        guard let observations = request.results else {
            return []
        }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let recognizedText = topCandidate.string
            
            // 检查是否匹配搜索文本
            if recognizedText.lowercased().contains(searchText.lowercased()) {
                // Vision 框架返回的坐标是归一化的 (0-1)，且原点在左下角
                let boundingBox = observation.boundingBox
                
                // 转换为实际像素坐标（原点在左上角）
                let x = boundingBox.origin.x * imageWidth
                let y = (1 - boundingBox.origin.y - boundingBox.height) * imageHeight
                let width = boundingBox.width * imageWidth
                let height = boundingBox.height * imageHeight
                
                let actualBox = CGRect(x: x, y: y, width: width, height: height)
                
                let location = TextLocation(
                    text: recognizedText,
                    boundingBox: actualBox,
                    confidence: topCandidate.confidence
                )
                
                results.append(location)
            }
        }
        
        return results
        
    } catch {
        return []
    }
}

// 主程序
let arguments = CommandLine.arguments

if arguments.count < 3 {
    print("""
    用法: swift ocr_coords.swift <图片路径> <搜索文本> [选项]
    
    选项:
      -cn        仅简体中文
      -tw        仅繁体中文
      -en        仅英文
      -json      输出 JSON 格式
      -center    输出中心点坐标
    
    示例:
      swift ocr_coords.swift button.png "允许"
      swift ocr_coords.swift button.png "Allow" -json
      swift ocr_coords.swift button.png "确定" -center
    """)
    exit(1)
}

let imagePath = arguments[1]
let searchText = arguments[2]

// 解析选项
var languages = ["zh-Hans", "zh-Hant", "en-US"]
var outputJson = false
var outputCenter = false

for i in 3..<arguments.count {
    switch arguments[i] {
    case "-cn":
        languages = ["zh-Hans"]
    case "-tw":
        languages = ["zh-Hant"]
    case "-en":
        languages = ["en-US"]
    case "-json":
        outputJson = true
    case "-center":
        outputCenter = true
    default:
        break
    }
}

let locations = findTextLocation(in: imagePath, searchText: searchText, languages: languages)

if locations.isEmpty {
    if outputJson {
        print("{\"found\": false, \"results\": []}")
    } else {
        print("未找到文本: \(searchText)")
    }
    exit(1)
} else {
    if outputJson {
        // JSON 输出
        print("{")
        print("  \"found\": true,")
        print("  \"count\": \(locations.count),")
        print("  \"results\": [")
        for (index, loc) in locations.enumerated() {
            let centerX = loc.boundingBox.midX
            let centerY = loc.boundingBox.midY
            // 转义 JSON 特殊字符
            let escapedText = loc.text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            print("    {")
            print("      \"text\": \"\(escapedText)\",")
            print("      \"confidence\": \(loc.confidence),")
            print("      \"boundingBox\": {")
            print("        \"x\": \(Int(loc.boundingBox.origin.x)),")
            print("        \"y\": \(Int(loc.boundingBox.origin.y)),")
            print("        \"width\": \(Int(loc.boundingBox.width)),")
            print("        \"height\": \(Int(loc.boundingBox.height))")
            print("      },")
            print("      \"center\": {")
            print("        \"x\": \(Int(centerX)),")
            print("        \"y\": \(Int(centerY))")
            print("      }")
            print("    }\(index < locations.count - 1 ? "," : "")")
        }
        print("  ]")
        print("}")
    } else if outputCenter {
        // 仅输出中心点
        for loc in locations {
            let centerX = Int(loc.boundingBox.midX)
            let centerY = Int(loc.boundingBox.midY)
            print("\(centerX),\(centerY)")
        }
    } else {
        // 普通输出
        print("找到 \(locations.count) 个匹配:")
        print("")
        for (index, loc) in locations.enumerated() {
            let centerX = Int(loc.boundingBox.midX)
            let centerY = Int(loc.boundingBox.midY)
            print("[\(index + 1)] 文本: \(loc.text)")
            print("    置信度: \(String(format: "%.2f%%", loc.confidence * 100))")
            print("    位置: x=\(Int(loc.boundingBox.origin.x)), y=\(Int(loc.boundingBox.origin.y))")
            print("    大小: width=\(Int(loc.boundingBox.width)), height=\(Int(loc.boundingBox.height))")
            print("    中心点: (\(centerX), \(centerY))")
            print("")
        }
    }
    exit(0)
}