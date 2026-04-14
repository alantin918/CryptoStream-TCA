import Foundation

/// Clean Architecture: Domain representation of a price update.
/// Kept separated from any WebSocket DTOs (Data Transfer Objects).
public struct PriceTick: Equatable, Sendable {
    public let symbol: String
    public let price: Double
    public let timestamp: Int64
    
    public init(symbol: String, price: Double, timestamp: Int64) {
        self.symbol = symbol
        self.price = price
        self.timestamp = timestamp
    }
}
