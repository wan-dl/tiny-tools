#!/usr/bin/env swift

import Foundation
import Vision
import AppKit

func recognizeText(in imagePath: String, searchText: String? = nil, languages: [String] = ["zh-Hans", "zh-Hant", "en-US"]) -> (found: Bool, allText: [String]) {
    guard let image = NSImage(contentsOfFile: imagePath),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return (false, [])
    }
    
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = languages
    
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    var allRecognizedText: [String] = []
    var foundText = false
    
    do {
        try handler.perform([request])
        
        guard let observations = request.results else {
            return (false, [])
        }
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            let recognizedText = topCandidate.string
            allRecognizedText.append(recognizedText)
            
            // 如果指定了搜索文本，检查是否匹配
            if let search = searchText {
                if recognizedText.lowercased().contains(search.lowercased()) {
                    foundText = true
                }
            }
        }
        
        return (foundText, allRecognizedText)
        
    } catch {
        return (false, [])
    }
}

// 主程序
let arguments = CommandLine.arguments

if arguments.count < 2 {
    print("用法:")
    print("  获取所有文本: swift ocr.swift <图片路径> [语言选项]")
    print("  搜索文本:     swift ocr.swift <图片路径> <搜索文本> [语言选项]")
    print("")
    print("语言选项: -cn(简体中文) -tw(繁体中文) -en(英文) -mix(混合,默认)")
    exit(1)
}

let imagePath = arguments[1]
var searchText: String? = nil
var languageOptionIndex = 2

// 判断第二个参数是语言选项还是搜索文本
if arguments.count > 2 {
    let secondArg = arguments[2]
    if secondArg.hasPrefix("-") {
        // 是语言选项，没有搜索文本
        searchText = nil
        languageOptionIndex = 2
    } else {
        // 是搜索文本
        searchText = secondArg
        languageOptionIndex = 3
    }
}

// 解析语言选项
var languages = ["zh-Hans", "zh-Hant", "en-US"]
if arguments.count > languageOptionIndex {
    switch arguments[languageOptionIndex] {
    case "-cn":
        languages = ["zh-Hans"]
    case "-tw":
        languages = ["zh-Hant"]
    case "-en":
        languages = ["en-US"]
    case "-mix":
        languages = ["zh-Hans", "zh-Hant", "en-US"]
    default:
        break
    }
}

let result = recognizeText(in: imagePath, searchText: searchText, languages: languages)

if let search = searchText {
    // 搜索模式：输出 true/false
    print(result.found ? "true" : "false")
    exit(result.found ? 0 : 1)
} else {
    // 获取所有文本模式：输出所有识别到的文本
    if result.allText.isEmpty {
        print("未识别到任何文本")
        exit(1)
    } else {
        for text in result.allText {
            print(text)
        }
        exit(0)
    }
}