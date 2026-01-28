# SemanticToolRouter

<p align="center">
  <a href="README.md">English</a> | <a href="README_CN.md">中文</a>
</p>

一个用于智能 LLM 工具路由的 Swift 包。通过根据用户输入过滤传递给 LLM 的工具，减少 token 消耗并提高准确性。

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 问题背景

当你的 LLM Agent 有很多工具（20+）时，每次请求都传递所有工具定义会导致：
- **Token 浪费**：工具定义消耗大量 token
- **准确性下降**：研究表明，50+ 工具时准确率从 95% 降至 20%
- **响应变慢**：更多 token = 更高延迟
- **成本增加**：更多 token = 更多开销

## 解决方案

SemanticToolRouter 在发送给 LLM **之前**智能过滤工具：

```
用户输入 → SemanticToolRouter → 仅相关工具 → LLM
```

## 功能特性

- 🎯 **关键词匹配**：快速、准确的已知模式匹配（支持中英文）
- 🧠 **语义匹配**：使用 Apple NaturalLanguage 嵌入处理模糊查询
- 💬 **问候语检测**：自动跳过 "你好"、"Hello" 等的工具匹配
- 🔄 **多轮对话**：考虑对话历史以获得更好的匹配
- ⚡ **零依赖**：仅使用 Apple 内置的 NaturalLanguage 框架
- 📦 **磁盘缓存**：缓存嵌入向量以加快后续加载

## 安装

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yvente/SemanticToolRouter.git", from: "1.0.0")
]
```

## 快速开始

```swift
import SemanticToolRouter

// 1. 定义你的工具
let tools = [
    SimpleTool(
        name: "get_weather",
        description: "获取某个位置的天气信息",
        keywords: ["天气", "气温", "weather", "forecast"]
    ),
    SimpleTool(
        name: "send_email",
        description: "发送邮件",
        keywords: ["邮件", "发邮件", "email", "send mail"]
    ),
    SimpleTool(
        name: "calculator",
        description: "执行数学计算",
        keywords: ["计算", "算", "calculate"]
    )
]

// 2. 创建路由器
let router = ToolRouter(tools: tools)

// 3. 等待嵌入就绪（语义匹配时推荐）
await router.waitForReady()

// 4. 路由用户输入
let result = await router.route("今天上海天气如何")

if result.shouldSkip {
    // 不需要工具（问候语、闲聊等）
    // 直接发送消息给 LLM，不传工具
} else {
    // 使用 result.tools 进行 LLM API 调用
    let toolsToSend = result.tools  // 只有相关工具！
}
```

## 与 OpenAI 集成

```swift
import OpenAI
import SemanticToolRouter

let router = ToolRouter(tools: myTools)

func chat(_ message: String) async throws -> String {
    // 等待路由器就绪（启动时调用一次即可）
    await router.waitForReady()
    
    let result = await router.route(message)
    
    // 转换为 OpenAI 格式
    let openAITools: [ChatQuery.ChatCompletionToolParam]? = result.shouldSkip 
        ? nil 
        : result.tools.map { tool in
            // 你的转换逻辑
        }
    
    let query = ChatQuery(
        messages: [...],
        tools: openAITools  // 只有相关工具！
    )
    
    return try await openAI.chats(query: query)
}
```

## 配置选项

```swift
let config = RouterConfig(
    // 语义匹配阈值 (0.0 - 1.0)
    similarityThreshold: 0.25,
    
    // 返回的最大工具数
    maxTools: 10,
    
    // 启用/禁用匹配方法
    enableKeywordMatching: true,
    enableSemanticMatching: true,
    
    // 自定义问候语模式
    greetingPatterns: ["你好", "hello", "hi"],
    
    // 工具组（如果一个匹配，包含相关的）
    toolGroups: [
        ["create_file", "read_file", "delete_file"],
        ["send_email", "read_email", "search_email"]
    ],
    
    // 磁盘缓存设置
    enableDiskCache: true,
    cacheFileName: "MyToolRouterCache.json",
    
    // 调试模式
    enableDebugInfo: true
)

let router = ToolRouter(tools: tools, config: config)
```

## 磁盘缓存

嵌入向量会缓存到磁盘，加快后续启动速度。缓存会在以下情况自动失效：
- 工具定义变更（名称、描述或关键词）
- 嵌入提供者变更
- 缓存版本变更

```swift
// 等待嵌入就绪（语义匹配时推荐）
await router.waitForReady()

// 检查嵌入是否就绪
if router.isReady {
    let result = router.route("查询内容")
}

// 手动清除磁盘缓存
router.clearDiskCache()
```

**性能对比：**

| 场景 | 首次启动 | 后续启动 |
|------|---------|---------|
| 无磁盘缓存 | 计算嵌入（~100ms） | 计算嵌入（~100ms） |
| 有磁盘缓存 | 计算 + 保存 | 从缓存加载（~5ms） |

## 多轮对话支持

```swift
// 包含最近的上下文以获得更好的匹配
let result = router.route(
    "帮我查一下",  // 没有上下文时模糊
    context: [
        "用户：北京天气怎么样",
        "助手：北京今天晴朗，25度"
    ]
)
// 会匹配天气工具，因为上下文提到了天气
```

## 自定义嵌入提供者

```swift
// 实现以获得更好的准确性（如 BGE、E5、OpenAI embeddings）
class MyEmbeddingProvider: EmbeddingProvider {
    var providerName: String { "MyProvider" }
    var dimension: Int { 1024 }
    
    func embed(_ text: String) -> [Double]? {
        // 你的嵌入逻辑
    }
}

let router = ToolRouter(
    tools: tools,
    embeddingProvider: MyEmbeddingProvider()
)
```

## 匹配流程

```
用户输入
    │
    ▼
┌─────────────────────────────────────┐
│ 第 0 步：问候语检测                   │
│ "你好", "Hello" → 跳过（不需要工具）   │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 第 1 步：关键词匹配（快速）            │
│ 输入包含 "天气" → get_weather        │
└─────────────────────────────────────┘
    │ （未匹配）
    ▼
┌─────────────────────────────────────┐
│ 第 2 步：语义匹配                     │
│ 与嵌入向量计算余弦相似度               │
└─────────────────────────────────────┘
    │ （未匹配）
    ▼
┌─────────────────────────────────────┐
│ 第 3 步：回退                         │
│ 返回所有工具                          │
└─────────────────────────────────────┘
```

## 性能表现

| 场景 | 发送的工具数 | Token 节省 |
|------|------------|-----------|
| 天气查询 | 2 个而非 44 个 | ~95% |
| 问候语 | 0 个而非 44 个 | 100% |
| 模糊查询 | 5-10 个而非 44 个 | ~80% |

## 系统要求

- macOS 14.0+ / iOS 17.0+
- Swift 5.9+

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 贡献

欢迎贡献！请先阅读贡献指南。
