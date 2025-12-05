## jqc

jqc: 命令行json处理器，类似jq，但支持解析带有注释的json文件。

```shell
// 使用方法
cat abc.json | jqc '.'
```


## mobile_device_probe

mobile_device_probe: Mac电脑手机设备检测（包含android真机、ios真机、鸿蒙真机、ios模拟器）

```shell
mobile_device_probe --help
mobile_device_probe usb
mobile_device_probe android
mobile_device_probe ios
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