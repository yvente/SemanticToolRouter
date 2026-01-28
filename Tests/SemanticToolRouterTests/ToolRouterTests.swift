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
    
    func test_weatherQuery_shouldReturnWeatherTool() {
        // Chinese
        let result1 = router.route("今天上海天气如何")
        XCTAssertFalse(result1.shouldSkip)
        XCTAssertTrue(result1.tools.contains { $0.name == "get_weather" })
        XCTAssertEqual(result1.method, .keyword)
        
        // English
        let result2 = router.route("What's the weather forecast?")
        XCTAssertFalse(result2.shouldSkip)
        XCTAssertTrue(result2.tools.contains { $0.name == "get_weather" })
    }
    
    func test_greeting_shouldSkip() {
        let greetings = ["你好", "Hello", "Hi", "早上好", "Thanks", "再见"]
        
        for greeting in greetings {
            let result = router.route(greeting)
            XCTAssertTrue(result.shouldSkip, "'\(greeting)' should be skipped")
            XCTAssertTrue(result.tools.isEmpty)
            XCTAssertEqual(result.method, .skipped)
        }
    }
    
    func test_emailQuery_shouldReturnEmailTool() {
        let result = router.route("帮我发邮件")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "send_email" })
    }
    
    func test_calculatorQuery_shouldReturnCalculatorTool() {
        let result = router.route("帮我计算 100 + 200")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "calculator" })
    }
    
    func test_reminderQuery_shouldReturnReminderTool() {
        let result = router.route("提醒我明天开会")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "create_reminder" })
    }
    
    func test_calendarQuery_shouldReturnCalendarTool() {
        let result = router.route("查看我的日程")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertTrue(result.tools.contains { $0.name == "get_calendar" })
    }
    
    // MARK: - Edge Cases
    
    func test_emptyInput_shouldSkip() {
        let result = router.route("")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_shortInput_shouldSkip() {
        let result = router.route("hi")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_noKeywordMatch_shouldFallback() {
        // Disable semantic matching, so this should fallback
        let result = router.route("帮我做一些随机的事情")
        XCTAssertFalse(result.shouldSkip)
        XCTAssertEqual(result.method, .fallback)
        XCTAssertEqual(result.tools.count, router.allTools.count)
    }
    
    // MARK: - Context Tests
    
    func test_routeWithContext_shouldConsiderContext() {
        let result = router.route(
            "帮我查一下",
            context: ["用户说：天气怎么样"]
        )
        // Context contains "天气", should match weather tool
        XCTAssertTrue(result.tools.contains { $0.name == "get_weather" })
    }
    
    // MARK: - Configuration Tests
    
    func test_customGreetingPatterns_shouldWork() {
        let customConfig = RouterConfig(
            greetingPatterns: ["custom_greeting"]
        )
        let customRouter = ToolRouter(tools: router.allTools, config: customConfig)
        
        let result = customRouter.route("custom_greeting")
        XCTAssertTrue(result.shouldSkip)
    }
    
    func test_disableKeywordMatching_shouldFallback() {
        let noKeywordConfig = RouterConfig(
            enableKeywordMatching: false,
            enableSemanticMatching: false
        )
        let noKeywordRouter = ToolRouter(tools: router.allTools, config: noKeywordConfig)
        
        let result = noKeywordRouter.route("天气怎么样")
        XCTAssertEqual(result.method, .fallback)
    }
}
