# SemanticToolRouter

A Swift package for intelligent LLM tool routing. Reduce token consumption and improve accuracy by filtering which tools to pass to your LLM based on user input.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## The Problem

When your LLM agent has many tools (20+), passing all tool definitions to every request causes:
- **Token waste**: Tool definitions consume significant tokens
- **Accuracy degradation**: Research shows accuracy drops from 95% to 20% with 50+ tools
- **Slower responses**: More tokens = more latency
- **Higher costs**: More tokens = more $$

## The Solution

SemanticToolRouter intelligently filters tools **before** sending to the LLM:

```
User Input → SemanticToolRouter → Relevant Tools Only → LLM
```

## Features

- 🎯 **Keyword Matching**: Fast, accurate matching for known patterns (Chinese + English)
- 🧠 **Semantic Matching**: Apple NaturalLanguage embeddings for ambiguous queries
- 💬 **Greeting Detection**: Automatically skips tool matching for "你好", "Hello", etc.
- 🔄 **Multi-turn Context**: Consider conversation history for better matching
- ⚡ **Zero Dependencies**: Uses only Apple's built-in NaturalLanguage framework
- 📦 **Disk Caching**: Cache embeddings for faster subsequent loads

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/user/SemanticToolRouter.git", from: "1.0.0")
]
```

## Quick Start

```swift
import SemanticToolRouter

// 1. Define your tools
let tools = [
    SimpleTool(
        name: "get_weather",
        description: "Get weather information for a location",
        keywords: ["天气", "气温", "weather", "forecast"]
    ),
    SimpleTool(
        name: "send_email",
        description: "Send an email message",
        keywords: ["邮件", "发邮件", "email", "send mail"]
    ),
    SimpleTool(
        name: "calculator",
        description: "Perform mathematical calculations",
        keywords: ["计算", "算", "calculate"]
    )
]

// 2. Create router
let router = ToolRouter(tools: tools)

// 3. Route user input
let result = router.route("今天上海天气如何")

if result.shouldSkip {
    // No tools needed (greeting, chat, etc.)
    // Just send message to LLM without tools
} else {
    // Use result.tools for LLM API call
    let toolsToSend = result.tools  // Only relevant tools!
}
```

## Integration with OpenAI

```swift
import OpenAI
import SemanticToolRouter

let router = ToolRouter(tools: myTools)

func chat(_ message: String) async throws -> String {
    let result = router.route(message)
    
    // Convert to OpenAI format
    let openAITools: [ChatQuery.ChatCompletionToolParam]? = result.shouldSkip 
        ? nil 
        : result.tools.map { tool in
            // Your conversion logic
        }
    
    let query = ChatQuery(
        messages: [...],
        tools: openAITools  // Only relevant tools!
    )
    
    return try await openAI.chats(query: query)
}
```

## Configuration

```swift
let config = RouterConfig(
    // Semantic matching threshold (0.0 - 1.0)
    similarityThreshold: 0.25,
    
    // Maximum tools to return
    maxTools: 10,
    
    // Enable/disable matching methods
    enableKeywordMatching: true,
    enableSemanticMatching: true,
    
    // Custom greeting patterns
    greetingPatterns: ["你好", "hello", "hi"],
    
    // Tool groups (if one matches, include related)
    toolGroups: [
        ["create_file", "read_file", "delete_file"],
        ["send_email", "read_email", "search_email"]
    ],
    
    // Debug mode
    enableDebugInfo: true
)

let router = ToolRouter(tools: tools, config: config)
```

## Multi-turn Conversation

```swift
// Include recent context for better matching
let result = router.route(
    "帮我查一下",  // Ambiguous without context
    context: [
        "用户：北京天气怎么样",
        "助手：北京今天晴朗，25度"
    ]
)
// Will match weather tool because context mentions 天气
```

## Custom Embedding Provider

```swift
// Implement for better accuracy (e.g., BGE, E5, OpenAI embeddings)
class MyEmbeddingProvider: EmbeddingProvider {
    var providerName: String { "MyProvider" }
    var dimension: Int { 1024 }
    
    func embed(_ text: String) -> [Double]? {
        // Your embedding logic
    }
}

let router = ToolRouter(
    tools: tools,
    embeddingProvider: MyEmbeddingProvider()
)
```

## Matching Flow

```
User Input
    │
    ▼
┌─────────────────────────────────────┐
│ Step 0: Greeting Detection          │
│ "你好", "Hello" → Skip (no tools)   │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ Step 1: Keyword Matching (Fast)     │
│ Input contains "天气" → get_weather │
└─────────────────────────────────────┘
    │ (no match)
    ▼
┌─────────────────────────────────────┐
│ Step 2: Semantic Matching           │
│ Cosine similarity with embeddings   │
└─────────────────────────────────────┘
    │ (no match)
    ▼
┌─────────────────────────────────────┐
│ Step 3: Fallback                    │
│ Return all tools                    │
└─────────────────────────────────────┘
```

## Performance

| Scenario | Tools Sent | Token Savings |
|----------|-----------|---------------|
| Weather query | 2 instead of 44 | ~95% |
| Greeting | 0 instead of 44 | 100% |
| Ambiguous | 5-10 instead of 44 | ~80% |

## Requirements

- macOS 14.0+ / iOS 17.0+
- Swift 5.9+

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read the contribution guidelines first.
