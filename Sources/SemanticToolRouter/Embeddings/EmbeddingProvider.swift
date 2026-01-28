import Foundation

// MARK: - Embedding Provider Protocol
// MARK: - 嵌入提供者协议

/// Protocol for semantic embedding providers
/// 语义嵌入提供者协议
///
/// Implementations:
/// - `NLEmbeddingProvider`: Apple NaturalLanguage framework (built-in, zero dependency)
/// - Future: `BGEEmbeddingProvider`, `OpenAIEmbeddingProvider`, etc.
public protocol EmbeddingProvider: Sendable {
    /// Provider name for identification
    /// 提供者名称用于识别
    var providerName: String { get }
    
    /// Embedding vector dimension
    /// 嵌入向量维度
    var dimension: Int { get }
    
    /// Generate embedding vector for text
    /// 为文本生成嵌入向量
    /// - Parameter text: Input text
    /// - Returns: Embedding vector, or nil if failed
    func embed(_ text: String) -> [Double]?
    
    /// Generate embeddings for multiple texts (batch)
    /// 为多个文本生成嵌入向量（批量）
    /// - Parameter texts: Array of input texts
    /// - Returns: Array of embedding vectors (nil for failed items)
    func embed(_ texts: [String]) -> [[Double]?]
    
    /// Calculate cosine similarity between two vectors
    /// 计算两个向量之间的余弦相似度
    /// - Parameters:
    ///   - vector1: First embedding vector
    ///   - vector2: Second embedding vector
    /// - Returns: Similarity score between -1 and 1
    func cosineSimilarity(_ vector1: [Double], _ vector2: [Double]) -> Double
    
    /// Check if the provider is available
    /// 检查提供者是否可用
    func isAvailable() -> Bool
}

// MARK: - Default Implementations

extension EmbeddingProvider {
    /// Default batch embedding implementation (sequential)
    /// 默认批量嵌入实现（顺序处理）
    public func embed(_ texts: [String]) -> [[Double]?] {
        return texts.map { embed($0) }
    }
    
    /// Default cosine similarity implementation
    /// 默认余弦相似度实现
    public func cosineSimilarity(_ vector1: [Double], _ vector2: [Double]) -> Double {
        guard vector1.count == vector2.count, !vector1.isEmpty else {
            return 0.0
        }
        
        var dotProduct: Double = 0.0
        var norm1: Double = 0.0
        var norm2: Double = 0.0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            norm1 += vector1[i] * vector1[i]
            norm2 += vector2[i] * vector2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        guard denominator > 0 else { return 0.0 }
        
        return dotProduct / denominator
    }
    
    /// Default availability check
    /// 默认可用性检查
    public func isAvailable() -> Bool {
        return true
    }
}
