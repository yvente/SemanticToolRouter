import Foundation

// MARK: - Tool Router
// MARK: - 工具路由器

/// Semantic tool router for intelligent LLM tool filtering
/// 语义工具路由器，用于智能 LLM 工具过滤
///
/// Usage:
/// ```swift
/// let tools = [
///     SimpleTool(name: "weather", description: "Get weather", keywords: ["天气", "weather"]),
///     SimpleTool(name: "email", description: "Send email", keywords: ["邮件", "email"])
/// ]
///
/// let router = ToolRouter(tools: tools)
/// let result = router.route("今天天气如何")
///
/// if result.shouldSkip {
///     // No tools needed (greeting, chat, etc.)
/// } else {
///     // Use result.tools for LLM function calling
/// }
/// ```
public final class ToolRouter<Tool: RoutableTool>: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let tools: [Tool]
    private let config: RouterConfig
    private let embeddingProvider: any EmbeddingProvider
    
    // Cached embeddings
    private var toolEmbeddings: [String: CachedEmbedding] = [:]
    private var isEmbeddingsReady: Bool = false
    private let embeddingsLock = NSLock()
    
    private struct CachedEmbedding: Codable {
        let name: String
        let description: String
        let embedding: [Double]
        let keywords: [String]
        let keywordEmbeddings: [[Double]]
    }
    
    // MARK: - Initialization
    
    /// Create a new ToolRouter
    /// 创建新的 ToolRouter
    /// - Parameters:
    ///   - tools: Array of tools to route
    ///   - config: Router configuration
    ///   - embeddingProvider: Embedding provider (defaults to NLEmbeddingProvider)
    public init(
        tools: [Tool],
        config: RouterConfig = .default,
        embeddingProvider: (any EmbeddingProvider)? = nil
    ) {
        self.tools = tools
        self.config = config
        self.embeddingProvider = embeddingProvider ?? NLEmbeddingProvider()
        
        // Pre-compute embeddings in background
        if config.enableSemanticMatching {
            Task.detached(priority: .utility) { [weak self] in
                await self?.precomputeEmbeddings()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Route user input to relevant tools
    /// 将用户输入路由到相关工具
    /// - Parameter input: User's message
    /// - Returns: Route result with matched tools
    public func route(_ input: String) -> RouteResult<Tool> {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Step 0: Check for greeting/chat (skip tool matching)
        if shouldSkipToolMatching(input) {
            return .skip()
        }
        
        // Step 1: Keyword matching (fast path)
        if config.enableKeywordMatching {
            let keywordMatched = keywordMatch(input)
            if !keywordMatched.isEmpty {
                let expanded = expandWithRelatedTools(keywordMatched)
                let matchedTools = tools.filter { expanded.contains($0.name) }
                
                return RouteResult(
                    tools: matchedTools,
                    confidence: 1.0,
                    method: .keyword,
                    shouldSkip: false,
                    debugInfo: config.enableDebugInfo ? DebugInfo(
                        input: input,
                        scores: matchedTools.map { ToolScore(toolName: $0.name, score: 1.0) },
                        elapsedTime: CFAbsoluteTimeGetCurrent() - startTime
                    ) : nil
                )
            }
        }
        
        // Step 2: Semantic matching (fallback)
        if config.enableSemanticMatching {
            let semanticResult = semanticMatch(input)
            if !semanticResult.isEmpty {
                let expanded = expandWithRelatedTools(Set(semanticResult.map { $0.0 }))
                let matchedTools = tools.filter { expanded.contains($0.name) }
                let avgScore = semanticResult.map { $0.1 }.reduce(0, +) / Double(max(semanticResult.count, 1))
                
                return RouteResult(
                    tools: matchedTools,
                    confidence: avgScore,
                    method: .semantic,
                    shouldSkip: false,
                    debugInfo: config.enableDebugInfo ? DebugInfo(
                        input: input,
                        scores: semanticResult.map { ToolScore(toolName: $0.0, score: $0.1) },
                        elapsedTime: CFAbsoluteTimeGetCurrent() - startTime
                    ) : nil
                )
            }
        }
        
        // Step 3: Fallback to all tools
        return RouteResult(
            tools: tools,
            confidence: 0.0,
            method: .fallback,
            shouldSkip: false,
            debugInfo: config.enableDebugInfo ? DebugInfo(
                input: input,
                scores: [],
                elapsedTime: CFAbsoluteTimeGetCurrent() - startTime
            ) : nil
        )
    }
    
    /// Route with conversation context
    /// 带对话上下文的路由
    /// - Parameters:
    ///   - input: Current user message
    ///   - context: Previous messages for context
    /// - Returns: Route result with matched tools
    public func route(_ input: String, context: [String]) -> RouteResult<Tool> {
        // Combine recent context with current input
        let combinedInput = (context.suffix(4) + [input]).joined(separator: " ")
        return route(combinedInput)
    }
    
    /// Get all registered tools
    /// 获取所有注册的工具
    public var allTools: [Tool] {
        return tools
    }
    
    // MARK: - Private Methods
    
    private func shouldSkipToolMatching(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Too short
        if trimmed.count < config.minInputLength {
            return true
        }
        
        // Check greeting patterns
        let lowercased = trimmed.lowercased()
        for pattern in config.greetingPatterns {
            if lowercased == pattern ||
               lowercased.hasPrefix(pattern + " ") ||
               lowercased.hasSuffix(" " + pattern) ||
               lowercased == pattern + "!" ||
               lowercased == pattern + "." {
                return true
            }
        }
        
        return false
    }
    
    private func keywordMatch(_ input: String) -> Set<String> {
        let lowercased = input.lowercased()
        var matched = Set<String>()
        
        for tool in tools {
            for keyword in tool.keywords {
                if lowercased.contains(keyword.lowercased()) {
                    matched.insert(tool.name)
                    break
                }
            }
        }
        
        return matched
    }
    
    private func semanticMatch(_ input: String) -> [(String, Double)] {
        embeddingsLock.lock()
        let ready = isEmbeddingsReady
        let embeddings = toolEmbeddings
        embeddingsLock.unlock()
        
        guard ready, let inputEmbedding = embeddingProvider.embed(input) else {
            return []
        }
        
        var scores: [(String, Double)] = []
        
        for (toolName, cached) in embeddings {
            let descScore = embeddingProvider.cosineSimilarity(inputEmbedding, cached.embedding)
            
            var maxKeywordScore: Double = 0.0
            for keywordEmb in cached.keywordEmbeddings {
                let score = embeddingProvider.cosineSimilarity(inputEmbedding, keywordEmb)
                maxKeywordScore = max(maxKeywordScore, score)
            }
            
            let combined = descScore * 0.6 + maxKeywordScore * 0.4
            
            if combined >= config.similarityThreshold {
                scores.append((toolName, combined))
            }
        }
        
        scores.sort { $0.1 > $1.1 }
        return Array(scores.prefix(config.maxTools))
    }
    
    private func expandWithRelatedTools(_ matched: Set<String>) -> Set<String> {
        var expanded = matched
        
        for group in config.toolGroups {
            if group.contains(where: { matched.contains($0) }) {
                for tool in group.prefix(3) {
                    expanded.insert(tool)
                }
            }
        }
        
        return expanded
    }
    
    private func precomputeEmbeddings() async {
        var newEmbeddings: [String: CachedEmbedding] = [:]
        
        for tool in tools {
            guard let descEmbedding = embeddingProvider.embed(tool.description) else {
                continue
            }
            
            var keywordEmbeddings: [[Double]] = []
            for keyword in tool.keywords {
                if let emb = embeddingProvider.embed(keyword) {
                    keywordEmbeddings.append(emb)
                }
            }
            
            newEmbeddings[tool.name] = CachedEmbedding(
                name: tool.name,
                description: tool.description,
                embedding: descEmbedding,
                keywords: tool.keywords,
                keywordEmbeddings: keywordEmbeddings
            )
        }
        
        embeddingsLock.withLock {
            toolEmbeddings = newEmbeddings
            isEmbeddingsReady = true
        }
    }
}
