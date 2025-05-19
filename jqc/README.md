# About

jqc: 命令行json处理器，类似jq，但支持解析带有注释的json文件。

### 编译jqc.c

```shell
gcc jqc.c cJSON.c -o jqc
```

### 如何使用？

```
cat abc.json | jqc '.'
```