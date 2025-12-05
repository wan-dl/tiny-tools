//
//  DeviceScanner.swift
//

import Foundation
import IOKit
import IOKit.usb

// Android Vendor IDs
let androidVendors: Set<UInt16> = [
    0x18D1, // Google
    0x04E8, // Samsung
    0x12D1, // Huawei
    0x2717, // Xiaomi
    0x2A70  // OnePlus
]

// iOS Real Device Product IDs
let iosProductIds: Set<UInt16> = [
    0x12A8, // Normal USB mux
    0x12A7, // Recovery
    0x12AB, // DFU
    0x12AD  // Diagnostics
]

// MARK: - Android ADB Detection
func isAndroidAdbEnabled(device: io_object_t) -> Bool {
    var iterator: io_iterator_t = 0
    if IORegistryEntryCreateIterator(device, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) != KERN_SUCCESS {
        return false
    }

    var entry = IOIteratorNext(iterator)
    while entry != 0 {
        let cls = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceClass as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int
        let sub = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceSubClass as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int
        let pro = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceProtocol as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int

        if cls == 0xFF && sub == 0x42 && pro == 0x01 {
            IOObjectRelease(entry)
            IOObjectRelease(iterator)
            return true
        }

        IOObjectRelease(entry)
        entry = IOIteratorNext(iterator)
    }

    IOObjectRelease(iterator)
    return false
}

// MARK: - Detect Real iPhone/iPad
func isRealIOSDevice(vendorID: UInt16, productID: UInt16, device: io_object_t) -> Bool {
    if vendorID != 0x05AC { return false }
    if !iosProductIds.contains(productID) { return false }

    var iterator: io_iterator_t = 0
    if IORegistryEntryCreateIterator(device, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) != KERN_SUCCESS {
        return false
    }

    var entry = IOIteratorNext(iterator)
    while entry != 0 {
        let cls = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceClass as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int
        let sub = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceSubClass as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int
        let pro = IORegistryEntryCreateCFProperty(entry, kUSBInterfaceProtocol as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int

        if cls == 6 && sub == 1 && pro == 1 {
            IOObjectRelease(entry)
            IOObjectRelease(iterator)
            return true
        }

        IOObjectRelease(entry)
        entry = IOIteratorNext(iterator)
    }

    IOObjectRelease(iterator)
    return false
}

// MARK: - Scan USB Devices (Android + iOS + harmony)
func scanUSBDevices() -> [[String: Any]] {
    guard let matchDict = IOServiceMatching(kIOUSBDeviceClassName) else { return [] }

    var iterator = io_iterator_t()
    if IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) != KERN_SUCCESS {
        return []
    }

    var results: [[String: Any]] = []
    var usbDevice = IOIteratorNext(iterator)

    while usbDevice != 0 {
        var vendorID: UInt16 = 0
        var productID: UInt16 = 0
        var serial = "Unknown"
        var name = "Unknown"
        var brand = "Unknown"

        if let v = IORegistryEntryCreateCFProperty(usbDevice, "idVendor" as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int {
            vendorID = UInt16(v)
        }

        if let p = IORegistryEntryCreateCFProperty(usbDevice, "idProduct" as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? Int {
            productID = UInt16(p)
        }

        if let s = IORegistryEntryCreateCFProperty(usbDevice, kUSBSerialNumberString as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
            serial = s
        }

        if let n = IORegistryEntryCreateCFProperty(usbDevice, kUSBProductString as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
            name = n
        }

        if let mfg = IORegistryEntryCreateCFProperty(usbDevice, kUSBVendorString as CFString, kCFAllocatorDefault, 0)?.takeUnretainedValue() as? String {
            brand = mfg
        }

        // Android / harmony detection
        if androidVendors.contains(vendorID) {
            var deviceType = "android"

            // 判断华为鸿蒙设备
            if vendorID == 0x12D1 && (brand.lowercased().contains("hisilicon") || name.lowercased().contains("hdc")) {
                deviceType = "harmony"
            }

            results.append([
                "type": deviceType,
                "name": name,
                "serial": serial,
                "brand": brand,
                "vendor_id": String(format: "0x%04X", vendorID),
                "product_id": String(format: "0x%04X", productID),
                "usb_debugging": isAndroidAdbEnabled(device: usbDevice)
            ])
        }

        // iOS real device
        if isRealIOSDevice(vendorID: vendorID, productID: productID, device: usbDevice) {
            results.append([
                "type": "ios",
                "name": name,
                "serial": serial,
                "brand": "Apple",
                "vendor_id": String(format: "0x%04X", vendorID),
                "product_id": String(format: "0x%04X", productID),
                "trusted": false
            ])
        }

        IOObjectRelease(usbDevice)
        usbDevice = IOIteratorNext(iterator)
    }

    IOObjectRelease(iterator)
    return results
}

// MARK: - Scan iOS Simulators
func scanIOSSimulators() -> [[String: Any]] {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Developer/CoreSimulator/Devices")

    guard let dirs = try? FileManager.default.contentsOfDirectory(
        at: path, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
    ) else { return [] }

    var list: [[String: Any]] = []

    for dir in dirs {
        let plistURL = dir.appendingPathComponent("device.plist")
        if !FileManager.default.fileExists(atPath: plistURL.path) { continue }

        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else { continue }

        let entry: [String: Any] = [
            "type": "ios_simulator",
            "name": dict["name"] as? String ?? "Unknown",
            "udid": dict["UDID"] as? String ?? dir.lastPathComponent,
            "runtime": dict["runtime"] as? String ?? "Unknown",
            "state": dict["state"] as? String ?? "Unknown",
            "device_type": dict["deviceType"] as? String ?? "Unknown"
        ]

        list.append(entry)
    }

    return list
}

// MARK: - Command line argument filter
enum DeviceFilter: String {
    case android
    case ios
    case iosSim = "ios-sim"
    case harmony
    case real
    case usb     // 新增 --usb 等同于 --real
    case all
}

func filterDevices(_ devices: [[String: Any]], _ filter: DeviceFilter) -> [[String: Any]] {
    switch filter {
    case .android:
        return devices.filter { ($0["type"] as? String) == "android" }
    case .ios:
        return devices.filter { ($0["type"] as? String) == "ios" }
    case .iosSim:
        return devices.filter { ($0["type"] as? String) == "ios_simulator" }
    case .harmony:
        return devices.filter { ($0["type"] as? String) == "harmony" }
    case .real, .usb:
        return devices.filter {
            let t = $0["type"] as? String
            return t == "ios" || t == "android" || t == "harmony"
        }
    case .all:
        return devices
    }
}

// MARK: - Custom JSON encoding with field order
func toOrderedJSON(_ devices: [[String: Any]]) -> String {
    var result = "[\n"
    
    for (index, device) in devices.enumerated() {
        result += "  {\n"
        
        // Define field order
        let fieldOrder = ["type", "name", "serial", "udid", "brand", "vendor_id", "product_id", "runtime", "state", "device_type", "usb_debugging", "trusted"]
        
        var fields: [String] = []
        for key in fieldOrder {
            guard let value = device[key] else { continue }
            
            let jsonValue: String
            if let str = value as? String {
                jsonValue = "\"\(str)\""
            } else if let bool = value as? Bool {
                jsonValue = bool ? "true" : "false"
            } else if let num = value as? Int {
                jsonValue = "\(num)"
            } else {
                jsonValue = "\(value)"
            }
            
            fields.append("    \"\(key)\" : \(jsonValue)")
        }
        
        result += fields.joined(separator: ",\n")
        result += "\n  }"
        if index < devices.count - 1 {
            result += ","
        }
        result += "\n"
    }
    
    result += "]"
    return result
}

func printHelp() {
    let helpText = """
    DeviceScanner - 扫描 macOS 上的设备

    用法:
      DeviceScanner [选项]

    选项:
      real          只显示真机 (iOS + Android + 鸿蒙)
      usb           等同于real
      all           显示所有设备（真机 + 模拟器） [默认]
      ios           只显示 iOS 真机
      ios-sim       只显示 iOS 模拟器
      android       只显示 Android 真机
      harmony       只显示鸿蒙手机
      --help, -h    显示本帮助信息
    """
    print(helpText)
}

// MARK: - Final Execution
let usbDevices = scanUSBDevices()         // 只包含真机
let iosSimulators = scanIOSSimulators()  // 模拟器

let args = CommandLine.arguments

if args.dropFirst().first?.lowercased() == "--help" || args.dropFirst().first?.lowercased() == "-h" {
    printHelp()
    exit(0)
}

let filterArg = args.dropFirst().first?.lowercased() ?? "usb"  // 转小写
let filter = DeviceFilter(rawValue: filterArg) ?? .usb

var filteredDevices: [[String: Any]] = []

switch filter {
case .iosSim:
    // 只显示模拟器
    filteredDevices = iosSimulators
case .all:
    // 全部设备，包括模拟器
    filteredDevices = usbDevices + iosSimulators
case .android, .ios, .harmony, .real, .usb:
    // 只显示真机
    filteredDevices = filterDevices(usbDevices, filter)
}

print(toOrderedJSON(filteredDevices))
