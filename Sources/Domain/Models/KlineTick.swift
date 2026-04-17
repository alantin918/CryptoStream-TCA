import Foundation

/// Clean Architecture: Domain representation of a K-line (Candlestick) update.
public struct KlineTick: Equatable, Sendable, Identifiable {
    public let symbol: String
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let eventTime: Int64
    public let openTime: Int64
    public let isClosed: Bool
    
    public var id: Int64 { openTime } // The open time of the kline uniquely identifies it
    
    public init(symbol: String, open: Double, high: Double, low: Double, close: Double, eventTime: Int64, openTime: Int64, isClosed: Bool) {
        self.symbol = symbol
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.eventTime = eventTime
        self.openTime = openTime
        self.isClosed = isClosed
    }
}
