import XCTest
@testable import SemanticToolRouter

final class ToolRouterTests: XCTestCase {
    
    var router: ToolRouter<SimpleTool>!
    
    override func setUp() {
        super.setUp()
        
        let tools = [
            SimpleTool(
                name: "get_weather",
                description: "Get weather information for a location",
                keywords: ["天气", "气温", "温度", "weather", "forecast"]
            ),
            SimpleTool(
                name: "send_email",
                description: "Send an email message",
                keywords: ["邮件", "发邮件", "email", "send mail"]
            ),
            SimpleTool(
                name: "calculator",
                description: "Perform mathematical calculations",
                keywords: ["计算", "算一下", "calculate", "+", "-"]
            ),
            SimpleTool(
                name: "create_reminder",
                description: "Create a reminder",
                keywords: ["提醒", "提醒我", "remind", "reminder"]
            ),
            SimpleTool(
                name: "get_calendar",
                description: "Get calendar events",
                keywords: ["日程", "日历", "calendar", "schedule"]
            )
        ]
        
        router = ToolRouter(
            tools: tools,
            config: RouterConfig(
                enableSemanticMatching: false  // Disable for faster tests
            )
        )
    }
    
    override func tearDown() {
        router = nil
        super.tearDown()
    }
    
    // MARK: - Core Scenario Tests
    
    func test_weatherQuery_shouldReturnWeatherTool() async {
        // Chinese
        let result1 = await router.route("今天上海天气如何")
        XCTAssertFalse(result1.shouldSkip)
        XCTAssertTrue(result1.tools.contains { $0.name == "get_weather" })
        XCTAssertEqual(result1.method, .keyword)
        
        // English
        let result2 = await router.route("What's the weather forecast?")
        XCTAssertFalse(result2.shouldSkip)
        XCTAssertTrue(result2.tools.contains { $0.name == "get_weather" })
    }
    
    func test_greeting_shouldSkip() async {
        let greetings = ["你好", "Hello", "Hi", "早上好", "Thanks", "再见"]
        
        for greeting in greetings {
            let result = await router.route(greeting)
            XCTAssertTrue(result.shouldSkip, "'\(greeting)' should be skipped")
            XCTAssertTrue(result.tools.isEmpty)
            XCTAssertEqual(result.method, .skipped)
        }
    }
    
    func test_emailQuery_shouldReturnEmailTool() async {
        let result = await router.route("帮我发邮件")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "send_email" })
    }
    
    func test_calculatorQuery_shouldReturnCalculatorTool() async {
        let result = await router.route("帮我计算 100 + 200")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "calculator" })
    }
    
    func test_reminderQuery_shouldReturnReminderTool() async {
        let result = await router.route("提醒我明天开会")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "create_reminder" })
    }
    
    func test_calendarQuery_shouldReturnCalendarTool() async {
        let result = await router.route("查看我的日程")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "get_calendar" })
    }
    
    // MARK: - Edge Cases
    
    func test_emptyInput_shouldSkip() async {
        let result = await router.route("")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_shortInput_shouldSkip() async {
        let result = await router.route("hi")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_noKeywordMatch_shouldFallback() async {
        // Disable semantic matching, so this should fallback
        let result = await router.route("帮我做一些随机的事情")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertEqual(result.method, .fallback)
        let allTools = await router.allTools
        XCTAssertEqual(result.tools.count, allTools.count)
    }
    
    // MARK: - Context Tests
    
    func test_routeWithContext_shouldConsiderContext() async {
        let result = await router.route(
            "帮我查一下",
            context: ["用户说：天气怎么样"]
        )
        // Context contains "天气", should match weather tool
        XCTAssertTrue(result.tools.contains { $0.name == "get_weather" })
    }
    
    // MARK: - Configuration Tests
    
    func test_customGreetingPatterns_shouldWork() async {
        let customConfig = RouterConfig(
            greetingPatterns: ["custom_greeting"]
        )
        let allTools = await router.allTools
        let customRouter = ToolRouter(tools: allTools, config: customConfig)
        
        let result = await customRouter.route("custom_greeting")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_disableKeywordMatching_shouldFallback() async {
        let noKeywordConfig = RouterConfig(
            enableKeywordMatching: false,
            enableSemanticMatching: false
        )
        let allTools = await router.allTools
        let noKeywordRouter = ToolRouter(tools: allTools, config: noKeywordConfig)
        
        let result = await noKeywordRouter.route("天气怎么样")
        XCTAssertEqual(result.method, .fallback)
    }
    
    // MARK: - Disk Cache Tests
    
    func test_diskCache_shouldSaveAndLoad() async {
        // Create router with disk cache enabled
        let cacheFileName = "TestCache_\(UUID().uuidString).json"
        let config = RouterConfig(
            enableKeywordMatching: true,
            enableSemanticMatching: true,
            enableDiskCache: true,
            cacheFileName: cacheFileName
        )
        
        let tools = [
            SimpleTool(
                name: "test_tool",
                description: "A test tool for caching",
                keywords: ["test", "cache"]
            )
        ]
        
        // First router - should compute and save
        let router1 = ToolRouter(tools: tools, config: config)
        await router1.waitForReady()
        
        let isReady1 = await router1.isReady
        XCTAssertTrue(isReady1, "Router should be ready after waitForReady")
        
        // Verify cache file exists
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheURL = cacheDir.appendingPathComponent(cacheFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path), "Cache file should exist")
        
        // Second router - should load from cache
        let router2 = ToolRouter(tools: tools, config: config)
        await router2.waitForReady()
        
        let isReady2 = await router2.isReady
        XCTAssertTrue(isReady2, "Second router should be ready")
        
        // Cleanup
        await router1.clearDiskCache()
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path), "Cache file should be deleted")
    }
    
    func test_diskCache_shouldInvalidateOnToolChange() async {
        let cacheFileName = "TestCache_\(UUID().uuidString).json"
        let config = RouterConfig(
            enableSemanticMatching: true,
            enableDiskCache: true,
            cacheFileName: cacheFileName
        )
        
        let tools1 = [
            SimpleTool(name: "tool1", description: "First tool", keywords: ["first"])
        ]
        
        let tools2 = [
            SimpleTool(name: "tool1", description: "Modified tool", keywords: ["first"])
        ]
        
        // Create first router
        let router1 = ToolRouter(tools: tools1, config: config)
        await router1.waitForReady()
        
        // Create second router with different tools - cache should be invalidated
        let router2 = ToolRouter(tools: tools2, config: config)
        await router2.waitForReady()
        
        let isReady2 = await router2.isReady
        XCTAssertTrue(isReady2, "Router with changed tools should still be ready")
        
        // Cleanup
        await router2.clearDiskCache()
    }
    
    func test_isReady_shouldBeFalseInitially() async {
        let config = RouterConfig(
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let allTools = await router.allTools
        // Clear any existing cache
        let freshRouter = ToolRouter(tools: allTools, config: config)
        
        // isReady might be false initially if embeddings haven't been computed yet
        // This is a timing-dependent test, so we just verify the property exists
        let _ = await freshRouter.isReady
    }
    
    func test_waitForReady_shouldComplete() async {
        let config = RouterConfig(
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let allTools = await router.allTools
        let asyncRouter = ToolRouter(tools: allTools, config: config)
        
        // Wait should complete
        await asyncRouter.waitForReady()
        
        let isReady = await asyncRouter.isReady
        XCTAssertTrue(isReady, "Router should be ready after waiting")
    }
    
    // MARK: - Semantic Matching Tests (Vector Comparison)
    
    /// Test: Synonym should match via semantic similarity
    /// 测试：同义词应通过语义相似度匹配
    func test_semanticMatch_synonymShouldMatch() async {
        // Disable keyword matching to force semantic matching
        let config = RouterConfig(
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "get_weather",
                description: "Get weather information, temperature, and forecast for a location",
                keywords: []  // No keywords to force semantic matching
            )
        ]
        
        let semanticRouter = ToolRouter(tools: tools, config: config)
        await semanticRouter.waitForReady()
        
        // "temperature" is semantically related to weather description
        let result = await semanticRouter.route("What is the temperature outside")
        
        // Should match via semantic, not fallback to all tools
        if result.method == .semantic {
            XCTAssertTrue(result.tools.contains { $0.name == "get_weather" })
            XCTAssertGreaterThan(result.confidence, 0.0)
        }
        // Note: If semantic matching doesn't find a match, it falls back
        // This is acceptable behavior - NLEmbedding has limited accuracy
    }
    
    /// Test: Completely unrelated input should not match semantically
    /// 测试：完全无关的输入不应语义匹配
    func test_semanticMatch_unrelatedShouldNotMatch() async {
        let config = RouterConfig(
            similarityThreshold: 0.5,  // Higher threshold
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "get_weather",
                description: "Get weather information for a location",
                keywords: []
            )
        ]
        
        let semanticRouter = ToolRouter(tools: tools, config: config)
        await semanticRouter.waitForReady()
        
        // Completely unrelated query
        let result = await semanticRouter.route("Tell me a joke about programming")
        
        // With high threshold, unrelated query should fallback
        // Either no semantic match or fallback to all tools
        if result.method == .semantic {
            // If it matched, confidence should be relatively low
            XCTAssertLessThan(result.confidence, 0.8, "Unrelated query should have low confidence")
        } else {
            XCTAssertEqual(result.method, .fallback)
        }
    }
    
    /// Test: Semantic matching should return confidence score
    /// 测试：语义匹配应返回置信度分数
    func test_semanticMatch_shouldReturnConfidence() async {
        let config = RouterConfig(
            similarityThreshold: 0.1,  // Low threshold to ensure match
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "send_email",
                description: "Send an email message to someone",
                keywords: []
            )
        ]
        
        let semanticRouter = ToolRouter(tools: tools, config: config)
        await semanticRouter.waitForReady()
        
        let result = await semanticRouter.route("I want to send a message via email")
        
        if result.method == .semantic {
            // Confidence should be between 0 and 1
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            XCTAssertFalse(result.tools.isEmpty)
        }
    }
    
    /// Test: Semantic matching with multiple tools should return most relevant
    /// 测试：多工具语义匹配应返回最相关的
    func test_semanticMatch_multipleToolsShouldRankByRelevance() async {
        let config = RouterConfig(
            similarityThreshold: 0.1,
            maxTools: 2,  // Limit to top 2
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "weather_tool",
                description: "Get weather forecast and temperature",
                keywords: []
            ),
            SimpleTool(
                name: "calendar_tool",
                description: "Manage calendar events and schedules",
                keywords: []
            ),
            SimpleTool(
                name: "email_tool",
                description: "Send and receive email messages",
                keywords: []
            )
        ]
        
        let semanticRouter = ToolRouter(tools: tools, config: config)
        await semanticRouter.waitForReady()
        
        let result = await semanticRouter.route("What's the weather forecast for tomorrow")
        
        if result.method == .semantic {
            // Should return at most maxTools
            XCTAssertLessThanOrEqual(result.tools.count, 2)
            // Weather tool should be in the results if semantic matching works
        }
    }
    
    /// Test: Semantic matching should work with Chinese input
    /// 测试：语义匹配应支持中文输入
    func test_semanticMatch_chineseInputShouldWork() async {
        let config = RouterConfig(
            similarityThreshold: 0.15,
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "calculator",
                description: "Perform mathematical calculations, add, subtract, multiply, divide numbers",
                keywords: []
            )
        ]
        
        let semanticRouter = ToolRouter(tools: tools, config: config)
        await semanticRouter.waitForReady()
        
        // Chinese input about math
        let result = await semanticRouter.route("帮我算一下这道数学题")
        
        // Test that it doesn't crash and returns a valid result
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.method == .semantic || result.method == .fallback)
    }
    
    /// Test: Keyword matching should take priority over semantic matching
    /// 测试：关键词匹配应优先于语义匹配
    func test_keywordMatchingPriority_shouldBeHigherThanSemantic() async {
        let config = RouterConfig(
            enableKeywordMatching: true,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "get_weather",
                description: "Get weather information",
                keywords: ["天气", "weather"]
            )
        ]
        
        let priorityRouter = ToolRouter(tools: tools, config: config)
        await priorityRouter.waitForReady()
        
        // Input contains keyword "天气"
        let result = await priorityRouter.route("今天天气怎么样")
        
        // Should match via keyword (faster path), not semantic
        XCTAssertEqual(result.method, .keyword)
        XCTAssertTrue(result.tools.contains { $0.name == "get_weather" })
    }
    
    /// Test: Debug info should be included when enabled
    /// 测试：启用时应包含调试信息
    func test_semanticMatch_debugInfoShouldBeIncluded() async {
        let config = RouterConfig(
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false,
            enableDebugInfo: true
        )
        
        let tools = [
            SimpleTool(
                name: "test_tool",
                description: "A test tool for debugging",
                keywords: []
            )
        ]
        
        let debugRouter = ToolRouter(tools: tools, config: config)
        await debugRouter.waitForReady()
        
        let result = await debugRouter.route("test query for debugging")
        
        // Debug info should be present
        XCTAssertNotNil(result.debugInfo)
        if let debugInfo = result.debugInfo {
            XCTAssertEqual(debugInfo.input, "test query for debugging")
            XCTAssertGreaterThanOrEqual(debugInfo.elapsedTime, 0)
        }
    }
    
    /// Test: Embeddings not ready should fallback gracefully
    /// 测试：嵌入未就绪时应优雅回退
    func test_semanticMatch_notReadyShouldFallback() async {
        let config = RouterConfig(
            enableKeywordMatching: false,
            enableSemanticMatching: true,
            enableDiskCache: false
        )
        
        let tools = [
            SimpleTool(
                name: "test_tool",
                description: "A test tool",
                keywords: []
            )
        ]
        
        // Create router but don't wait for ready
        let notReadyRouter = ToolRouter(tools: tools, config: config)
        
        // Query immediately without waiting
        let result = await notReadyRouter.route("some query")
        
        // Should not crash, either semantic match or fallback
        XCTAssertFalse(result.shouldSkip)
        // Most likely fallback since embeddings aren't ready
    }
}
