import Foundation

/// `PriceActor` is responsible for handling high-frequency data,
/// limiting UI updates, and preventing out-of-order data processing.
/// Isolated to an actor to guarantee thread-safe state access without Data Races.
public actor PriceActor {
    // State to maintain sequential consistency for multiple symbols
    private var lastProcessedTimestamps: [String: Int64] = [:]
    
    // State for Throttling for multiple symbols
    private var lastEmittedTimes: [String: ContinuousClock.Instant] = [:]
    
    private let clock: ContinuousClock
    private let minInterval: Duration
    
    /// Initializes the PriceActor with a specific throttling rate.
    /// - Parameter updatesPerSecond: The maximum number of updates allowed per second (default is 10Hz).
    public init(updatesPerSecond: Int = 10, clock: ContinuousClock = ContinuousClock()) {
        self.clock = clock
        // 10 Hz = 100 milliseconds
        self.minInterval = .milliseconds(1000 / updatesPerSecond)
    }
    
    /// Processes a single tick, returning the tick if it passes throttling and ordering rules.
    /// Otherwise, returns nil.
    public func process(next tick: PriceTick) -> PriceTick? {
        let symbol = tick.symbol
        let lastTimestamp = lastProcessedTimestamps[symbol, default: -1]
        
        // 1. Handle Out-of-Order Data per symbol
        guard tick.timestamp > lastTimestamp else {
            return nil
        }
        self.lastProcessedTimestamps[symbol] = tick.timestamp
        
        // 2. Throttling per symbol
        let now = clock.now
        let lastEmitted = lastEmittedTimes[symbol, default: now.advanced(by: .seconds(-3600))]
        
        if lastEmitted.duration(to: now) >= minInterval {
            self.lastEmittedTimes[symbol] = now
            return tick
        }
        
        // Data is dropped if it's too frequent
        return nil
    }
}
