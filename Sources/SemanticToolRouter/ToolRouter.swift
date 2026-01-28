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
///
/// // Wait for embeddings to be ready (recommended)
/// await router.waitForReady()
///
/// // Route user input
/// let result = await router.route("今天天气如何")
///
/// if result.shouldSkip {
///     // No tools needed (greeting, chat, etc.)
/// } else {
///     // Use result.tools for LLM function calling
/// }
/// ```
/// Error types for ToolRouter
/// ToolRouter 错误类型
public enum ToolRouterError: Error, Sendable {
    /// Timeout waiting for embeddings to be ready
    /// 等待嵌入就绪超时
    case timeout
    
    /// Failed to load cache from disk
    /// 从磁盘加载缓存失败
    case cacheLoadFailed(Error)
    
    /// Failed to save cache to disk
    /// 保存缓存到磁盘失败
    case cacheSaveFailed(Error)
}

public actor ToolRouter<Tool: RoutableTool> {
    
    // MARK: - Properties
    
    private let tools: [Tool]
    private let config: RouterConfig
    private let embeddingProvider: any EmbeddingProvider
    
    // Cached embeddings (actor-isolated, no lock needed)
    private var toolEmbeddings: [String: CachedEmbedding] = [:]
    private var isEmbeddingsReady: Bool = false
    
    // Initialization task for waitForReady() - nonisolated to allow assignment in init
    private nonisolated(unsafe) var initTask: Task<Void, Never>?
    
    /// Error handler callback for cache operations
    /// 缓存操作的错误处理回调
    private var _onCacheError: (@Sendable (ToolRouterError) -> Void)?
    
    /// Set the error handler callback for cache operations
    /// 设置缓存操作的错误处理回调
    public func setOnCacheError(_ handler: (@Sendable (ToolRouterError) -> Void)?) {
        _onCacheError = handler
    }
    
    /// Get the current error handler
    private var onCacheError: (@Sendable (ToolRouterError) -> Void)? {
        _onCacheError
    }
    
    // Cache version for invalidation when tools change
    private static var cacheVersion: String { "1.0" }
    
    private struct CachedEmbedding: Codable, Sendable {
        let name: String
        let description: String
        let embedding: [Double]
        let keywords: [String]
        let keywordEmbeddings: [[Double]]
    }
    
    /// Disk cache container with version and tool hash for invalidation
    /// 磁盘缓存容器，包含版本和工具哈希用于失效判断
    private struct DiskCache: Codable, Sendable {
        let version: String
        let toolsHash: String
        let providerName: String
        let embeddings: [String: CachedEmbedding]
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
            initTask = Task { [self] in
                await self.initializeEmbeddings()
            }
        }
    }
    
    /// Initialize embeddings: try loading from disk cache first, then compute if needed
    /// 初始化嵌入：首先尝试从磁盘缓存加载，如果需要则计算
    private func initializeEmbeddings() async {
        // Try to load from disk cache
        if config.enableDiskCache, let cached = loadFromDiskCache() {
            toolEmbeddings = cached
            isEmbeddingsReady = true
            return
        }
        
        // Compute embeddings
        await precomputeEmbeddings()
        
        // Save to disk cache
        if config.enableDiskCache {
            saveToDiskCache()
        }
        
        isEmbeddingsReady = true
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
    
    /// Check if embeddings are ready
    /// 检查嵌入是否就绪
    public var isReady: Bool {
        return isEmbeddingsReady
    }
    
    /// Wait for embeddings to be ready
    /// 等待嵌入就绪
    public func waitForReady() async {
        await initTask?.value
    }
    
    /// Wait for embeddings to be ready with timeout
    /// 带超时的等待嵌入就绪
    /// - Parameter timeout: Maximum time to wait
    /// - Throws: ToolRouterError.timeout if timeout is exceeded
    public func waitForReady(timeout: Duration) async throws {
        guard let task = initTask else { return }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await task.value
            }
            
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ToolRouterError.timeout
            }
            
            // Wait for first to complete
            try await group.next()
            
            // Cancel the other task
            group.cancelAll()
        }
    }
    
    /// Clear the disk cache
    /// 清除磁盘缓存
    public func clearDiskCache() {
        guard let url = cacheFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
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
        guard isEmbeddingsReady, let inputEmbedding = embeddingProvider.embed(input) else {
            return []
        }
        
        var scores: [(String, Double)] = []
        
        for (toolName, cached) in toolEmbeddings {
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
        
        toolEmbeddings = newEmbeddings
    }
    
    // MARK: - Disk Cache
    
    /// Get the cache file URL
    /// 获取缓存文件 URL
    private nonisolated func cacheFileURL() -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cacheDir.appendingPathComponent(config.cacheFileName)
    }
    
    /// Generate a hash of tools for cache invalidation
    /// 生成工具哈希用于缓存失效判断
    private nonisolated func computeToolsHash() -> String {
        var hasher = Hasher()
        for tool in tools.sorted(by: { $0.name < $1.name }) {
            hasher.combine(tool.name)
            hasher.combine(tool.description)
            hasher.combine(tool.keywords)
        }
        let hashValue = hasher.finalize()
        return String(format: "%08x", abs(hashValue))
    }
    
    /// Load embeddings from disk cache
    /// 从磁盘缓存加载嵌入
    /// - Returns: Cached embeddings if valid, nil otherwise
    private func loadFromDiskCache() -> [String: CachedEmbedding]? {
        guard let url = cacheFileURL() else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            let cache = try JSONDecoder().decode(DiskCache.self, from: data)
            
            // Validate cache
            guard cache.version == Self.cacheVersion,
                  cache.toolsHash == computeToolsHash(),
                  cache.providerName == embeddingProvider.providerName else {
                // Cache is stale, remove it
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            
            return cache.embeddings
        } catch {
            // Notify error via callback
            onCacheError?(.cacheLoadFailed(error))
            return nil
        }
    }
    
    /// Save embeddings to disk cache
    /// 保存嵌入到磁盘缓存
    private func saveToDiskCache() {
        guard let url = cacheFileURL() else { return }
        
        let cache = DiskCache(
            version: Self.cacheVersion,
            toolsHash: computeToolsHash(),
            providerName: embeddingProvider.providerName,
            embeddings: toolEmbeddings
        )
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: url, options: .atomic)
        } catch {
            // Notify error via callback
            onCacheError?(.cacheSaveFailed(error))
        }
    }
}
