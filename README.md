## Sing-box YAML Translator

从 clash 换到 sing-box 后，发现写 json 配置这件事实在是太恶心了。为了能继续用 yaml 愉快地写配置，我开发了这个工具，同时支持导入 clash 的 proxy provider 订阅。

### 使用方法

需要 ruby 语言环境，不需要额外的 gem 运行库。

```
main.rb [filename]
```

如果不指定文件名，程序将自动检查当前目录下的`config.yaml`和`config.yml`文件。

#### Clash Provider

```yaml
outbound-providers:
  example:
  	type: file # 订阅类型: file(本地文件) | http(在线链接)
  	url: https://example.com/sub/qweasdzxc # 订阅路径: ./config.yml
  # ...支持添加多个订阅
```

须配合 筛选代理集 功能使用。

#### 其他特性

1. 支持 clash 筛选节点功能（仅实现`use`、`filter`）
2. 支持 YAML Aliases