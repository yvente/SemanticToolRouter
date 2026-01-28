import Foundation

// MARK: - Router Configuration
// MARK: - 路由器配置

/// Configuration for ToolRouter
/// ToolRouter 配置
public struct RouterConfig: Sendable {
    
    // MARK: - Matching Settings
    
    /// Minimum similarity threshold for semantic matching (0.0 - 1.0)
    /// 语义匹配的最低相似度阈值（0.0 - 1.0）
    public var similarityThreshold: Double
    
    /// Maximum number of tools to return
    /// 返回的最大工具数量
    public var maxTools: Int
    
    /// Whether to enable keyword matching (fast path)
    /// 是否启用关键词匹配（快速路径）
    public var enableKeywordMatching: Bool
    
    /// Whether to enable semantic embedding matching (fallback)
    /// 是否启用语义嵌入匹配（回退方案）
    public var enableSemanticMatching: Bool
    
    // MARK: - Greeting Detection
    
    /// Patterns to detect greetings/chat (no tools needed)
    /// 检测问候语/闲聊的模式（不需要工具）
    public var greetingPatterns: [String]
    
    /// Minimum input length to consider (shorter = likely greeting)
    /// 考虑的最小输入长度（更短 = 可能是问候语）
    public var minInputLength: Int
    
    // MARK: - Tool Groups
    
    /// Tool groups for expansion (if one matches, include related)
    /// 工具组用于扩展（如果一个匹配，包含相关的）
    public var toolGroups: [[String]]
    
    // MARK: - Caching
    
    /// Whether to cache embeddings to disk
    /// 是否将嵌入缓存到磁盘
    public var enableDiskCache: Bool
    
    /// Cache file name
    /// 缓存文件名
    public var cacheFileName: String
    
    // MARK: - Debug
    
    /// Whether to include debug info in results
    /// 是否在结果中包含调试信息
    public var enableDebugInfo: Bool
    
    // MARK: - Initialization
    
    public init(
        similarityThreshold: Double = 0.25,
        maxTools: Int = 10,
        enableKeywordMatching: Bool = true,
        enableSemanticMatching: Bool = true,
        greetingPatterns: [String] = Self.defaultGreetingPatterns,
        minInputLength: Int = 3,
        toolGroups: [[String]] = [],
        enableDiskCache: Bool = true,
        cacheFileName: String = "SemanticToolRouterCache.json",
        enableDebugInfo: Bool = false
    ) {
        self.similarityThreshold = similarityThreshold
        self.maxTools = maxTools
        self.enableKeywordMatching = enableKeywordMatching
        self.enableSemanticMatching = enableSemanticMatching
        self.greetingPatterns = greetingPatterns
        self.minInputLength = minInputLength
        self.toolGroups = toolGroups
        self.enableDiskCache = enableDiskCache
        self.cacheFileName = cacheFileName
        self.enableDebugInfo = enableDebugInfo
    }
    
    /// Default configuration
    /// 默认配置
    public static let `default` = RouterConfig()
    
    /// Default greeting patterns (Chinese + English)
    /// 默认问候语模式（中英文）
    public static let defaultGreetingPatterns: [String] = [
        // Chinese
        "你好", "您好", "嗨", "哈喽",
        "早上好", "下午好", "晚上好", "早安", "晚安",
        "谢谢", "感谢", "多谢",
        "再见", "拜拜", "回见",
        "好的", "是的", "对", "行", "可以",
        "你是谁", "介绍一下", "你能做什么", "帮助",
        // English
        "hi", "hello", "hey", "howdy",
        "good morning", "good afternoon", "good evening", "good night",
        "thanks", "thank you", "thx",
        "bye", "goodbye", "see you",
        "ok", "okay", "yes", "sure", "alright"
    ]
}
