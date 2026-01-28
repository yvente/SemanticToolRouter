import Foundation
import NaturalLanguage

// MARK: - Apple NaturalLanguage Embedding Provider
// MARK: - Apple NaturalLanguage 嵌入提供者

/// Embedding provider using Apple's NaturalLanguage framework
/// 使用 Apple NaturalLanguage 框架的嵌入提供者
///
/// Pros:
/// - Zero dependency, built into macOS/iOS
/// - No model download required
/// - Fast inference
///
/// Cons:
/// - Lower accuracy compared to specialized models
/// - Limited control over model updates
/// - Chinese semantic understanding is moderate
public final class NLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    
    // MARK: - Properties
    
    public let providerName: String = "Apple NaturalLanguage"
    
    public var dimension: Int { 512 }
    
    // MARK: - Private Properties
    
    private var embeddingCache: [NLLanguage: [String: [Double]]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.semantictoolrouter.nlembedding.cache")
    private let maxCacheSize: Int
    
    // MARK: - Initialization
    
    public init(maxCacheSize: Int = 500) {
        self.maxCacheSize = maxCacheSize
    }
    
    // MARK: - EmbeddingProvider
    
    public func embed(_ text: String) -> [Double]? {
        let language = detectLanguage(text)
        
        // Check cache
        if let cached = getCachedEmbedding(text: text, language: language) {
            return cached
        }
        
        // Get embedding from NaturalLanguage
        guard let embedding = NLEmbedding.wordEmbedding(for: language) else {
            return embedSentence(text, language: language)
        }
        
        let vector = computeTextEmbedding(text, embedding: embedding, language: language)
        
        if let vector = vector {
            cacheEmbedding(text: text, vector: vector, language: language)
        }
        
        return vector
    }
    
    public func isAvailable() -> Bool {
        return NLEmbedding.wordEmbedding(for: .english) != nil
    }
    
    // MARK: - Private Methods
    
    private func detectLanguage(_ text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? .english
    }
    
    private func computeTextEmbedding(_ text: String, embedding: NLEmbedding, language: NLLanguage) -> [Double]? {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var vectors: [[Double]] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if let vector = embedding.vector(for: word) {
                vectors.append(vector.map { Double($0) })
            }
            return true
        }
        
        if vectors.isEmpty {
            return embedSentence(text, language: language)
        }
        
        return averageVectors(vectors)
    }
    
    private func embedSentence(_ text: String, language: NLLanguage) -> [Double]? {
        guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: language) else {
            if language != .english, let englishEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
                return englishEmbedding.vector(for: text)?.map { Double($0) }
            }
            return nil
        }
        
        return sentenceEmbedding.vector(for: text)?.map { Double($0) }
    }
    
    private func averageVectors(_ vectors: [[Double]]) -> [Double]? {
        guard !vectors.isEmpty else { return nil }
        
        let dimension = vectors[0].count
        var result = [Double](repeating: 0.0, count: dimension)
        
        for vector in vectors {
            guard vector.count == dimension else { continue }
            for i in 0..<dimension {
                result[i] += vector[i]
            }
        }
        
        let count = Double(vectors.count)
        for i in 0..<dimension {
            result[i] /= count
        }
        
        return result
    }
    
    // MARK: - Cache Management
    
    private func getCachedEmbedding(text: String, language: NLLanguage) -> [Double]? {
        cacheQueue.sync {
            return embeddingCache[language]?[text]
        }
    }
    
    private func cacheEmbedding(text: String, vector: [Double], language: NLLanguage) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.embeddingCache[language] == nil {
                self.embeddingCache[language] = [:]
            }
            
            if self.embeddingCache[language]!.count >= self.maxCacheSize {
                let keys = Array(self.embeddingCache[language]!.keys)
                for key in keys.prefix(self.maxCacheSize / 2) {
                    self.embeddingCache[language]!.removeValue(forKey: key)
                }
            }
            
            self.embeddingCache[language]![text] = vector
        }
    }
    
    /// Clear all cached embeddings
    /// 清除所有缓存的嵌入
    public func clearCache() {
        cacheQueue.async { [weak self] in
            self?.embeddingCache.removeAll()
        }
    }
}
