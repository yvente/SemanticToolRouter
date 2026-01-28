import Foundation

// MARK: - Route Result
// MARK: - 路由结果

/// Result of tool routing
/// 工具路由结果
public struct RouteResult<Tool: RoutableTool>: Sendable {
    /// Matched tools (may be empty)
    /// 匹配到的工具（可能为空）
    public let tools: [Tool]
    
    /// Confidence score (0.0 - 1.0)
    /// 置信度分数（0.0 - 1.0）
    public let confidence: Double
    
    /// Method used for matching
    /// 使用的匹配方法
    public let method: MatchMethod
    
    /// Whether to skip tool calling (greeting, chat, etc.)
    /// 是否跳过工具调用（问候语、闲聊等）
    public let shouldSkip: Bool
    
    /// Debug information
    /// 调试信息
    public let debugInfo: DebugInfo?
    
    public init(
        tools: [Tool],
        confidence: Double = 1.0,
        method: MatchMethod = .keyword,
        shouldSkip: Bool = false,
        debugInfo: DebugInfo? = nil
    ) {
        self.tools = tools
        self.confidence = confidence
        self.method = method
        self.shouldSkip = shouldSkip
        self.debugInfo = debugInfo
    }
    
    /// Create an empty result (no tools needed)
    /// 创建空结果（不需要工具）
    public static func skip() -> RouteResult {
        RouteResult(tools: [], confidence: 1.0, method: .skipped, shouldSkip: true)
    }
}

// MARK: - Match Method

/// Method used for matching
/// 匹配方法
public enum MatchMethod: String, Sendable {
    /// Matched via keyword matching (fast, high accuracy)
    /// 通过关键词匹配（快速、高准确率）
    case keyword
    
    /// Matched via semantic embedding similarity
    /// 通过语义嵌入相似度匹配
    case semantic
    
    /// No matching performed (greeting/chat detected)
    /// 未执行匹配（检测到问候语/闲聊）
    case skipped
    
    /// Fallback to all tools (matching failed)
    /// 回退到所有工具（匹配失败）
    case fallback
}

// MARK: - Debug Info

/// Debug information for troubleshooting
/// 用于排查问题的调试信息
public struct DebugInfo: Sendable {
    /// Input that was analyzed
    /// 被分析的输入
    public let input: String
    
    /// All match scores
    /// 所有匹配分数
    public let scores: [ToolScore]
    
    /// Time taken for matching (in seconds)
    /// 匹配耗时（秒）
    public let elapsedTime: Double
    
    public init(input: String, scores: [ToolScore], elapsedTime: Double) {
        self.input = input
        self.scores = scores
        self.elapsedTime = elapsedTime
    }
}

/// Score for a single tool
/// 单个工具的分数
public struct ToolScore: Sendable {
    public let toolName: String
    public let score: Double
    public let matchedKeyword: String?
    
    public init(toolName: String, score: Double, matchedKeyword: String? = nil) {
        self.toolName = toolName
        self.score = score
        self.matchedKeyword = matchedKeyword
    }
}
