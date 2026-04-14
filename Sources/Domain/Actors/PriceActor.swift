import Foundation

/// `PriceActor` is responsible for handling high-frequency data,
/// limiting UI updates, and preventing out-of-order data processing.
/// Isolated to an actor to guarantee thread-safe state access without Data Races.
public actor PriceActor {
    // State to maintain sequential consistency
    private var lastProcessedTimestamp: Int64 = -1
    
    // State for Throttling
    private var lastEmittedTime: ContinuousClock.Instant
    
    private let clock: ContinuousClock
    private let minInterval: Duration
    
    /// Initializes the PriceActor with a specific throttling rate.
    /// - Parameter updatesPerSecond: The maximum number of updates allowed per second (default is 10Hz).
    public init(updatesPerSecond: Int = 10, clock: ContinuousClock = ContinuousClock()) {
        self.clock = clock
        // 10 Hz = 100 milliseconds
        self.minInterval = .milliseconds(1000 / updatesPerSecond)
        // 初始化為很久以前，確保第一筆資料永遠能通過節流，不會被誤丟棄
        self.lastEmittedTime = clock.now.advanced(by: .seconds(-3600))
    }
    
    /// Processes a single tick, returning the tick if it passes throttling and ordering rules.
    /// Otherwise, returns nil.
    public func process(next tick: PriceTick) -> PriceTick? {
        // 1. Handle Out-of-Order Data
        // Ignore the data if its timestamp is older or equal to our last processed timestamp
        guard tick.timestamp > lastProcessedTimestamp else {
            return nil
        }
        self.lastProcessedTimestamp = tick.timestamp
        
        // 2. Throttling
        // Limit UI updates to our configured frequency
        let now = clock.now
        if lastEmittedTime.duration(to: now) >= minInterval {
            self.lastEmittedTime = now
            return tick
        }
        
        // Data is dropped if it's too frequent
        return nil
    }
}
