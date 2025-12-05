# About

mobile_device_probe: Mac电脑手机设备检测（包含android真机、ios真机、鸿蒙真机、ios模拟器）

### 编译swift

```shell
swiftc mobile_device_probe.swift -o mobile_device_probe
```

### 如何使用？

```
mobile_device_probe
mobile_device_probe --help
```

输出：

```
[
  {
    "type" : "ios",
    "name" : "iPhone",
    "serial" : "000081100012342424242",
    "brand" : "Apple",
    "vendor_id" : "0x05AC",
    "product_id" : "0x12A8",
    "trusted" : false
  }
]
```