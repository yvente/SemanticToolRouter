// SemanticToolRouter
// A Swift package for intelligent LLM tool routing
// 用于智能 LLM 工具路由的 Swift 包

// MARK: - Public API Exports
// All public types are automatically exported from their respective files

/*
 Usage Example:
 
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
         keywords: ["计算", "算", "calculate", "+", "-", "*", "/"]
     )
 ]
 
 // 2. Create router
 let router = ToolRouter(tools: tools)
 
 // 3. Route user input
 let result = router.route("今天上海天气如何")
 
 if result.shouldSkip {
     // User said "你好" or similar - no tools needed
     print("No tools needed for this input")
 } else {
     // Use matched tools for LLM API call
     print("Matched tools: \(result.tools.map { $0.name })")
     print("Method: \(result.method)")
     print("Confidence: \(result.confidence)")
 }
 
 // 4. With conversation context
 let contextResult = router.route(
     "帮我查一下",
     context: ["用户：北京天气怎么样", "助手：北京今天晴朗"]
 )
 ```
 
 Key Features:
 - Keyword matching (fast, high accuracy)
 - Semantic embedding matching (handles ambiguous queries)
 - Greeting/chat detection (skips tool matching for "你好", "Hello", etc.)
 - Multi-turn conversation context support
 - Configurable thresholds and tool groups
 - Zero external dependencies (uses Apple NaturalLanguage)
 
 For custom embedding providers, implement the `EmbeddingProvider` protocol.
 */
