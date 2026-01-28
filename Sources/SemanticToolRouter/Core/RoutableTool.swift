import Foundation

// MARK: - Routable Tool Protocol
// MARK: - 可路由工具协议

/// Protocol that tools must conform to for routing
/// 工具必须遵循的路由协议
///
/// Example:
/// ```swift
/// struct MyTool: RoutableTool {
///     let name = "get_weather"
///     let description = "Get weather information for a location"
///     let keywords = ["天气", "weather", "forecast", "温度"]
/// }
/// ```
public protocol RoutableTool: Sendable {
    /// Unique identifier for the tool
    /// 工具的唯一标识符
    var name: String { get }
    
    /// Description of what the tool does (used for semantic matching)
    /// 工具功能描述（用于语义匹配）
    var description: String { get }
    
    /// Keywords that trigger this tool (used for keyword matching)
    /// 触发此工具的关键词（用于关键词匹配）
    var keywords: [String] { get }
}

// MARK: - Default Implementation

extension RoutableTool {
    /// Default empty keywords - relies on semantic matching only
    /// 默认空关键词 - 仅依赖语义匹配
    public var keywords: [String] { [] }
}

// MARK: - Simple Tool Implementation

/// A simple concrete implementation of RoutableTool
/// RoutableTool 的简单具体实现
public struct SimpleTool: RoutableTool {
    public let name: String
    public let description: String
    public let keywords: [String]
    
    public init(name: String, description: String, keywords: [String] = []) {
        self.name = name
        self.description = description
        self.keywords = keywords
    }
}
