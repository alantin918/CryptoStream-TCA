import Foundation

/// `PriceActor` is responsible for handling high-frequency data,
/// limiting UI updates, and preventing out-of-order data processing.
/// Isolated to an actor to guarantee thread-safe state access without Data Races.
///
/// Throttle mechanism uses the PriceTick's own timestamp (milliseconds) for
/// deterministic behaviour across all environments (local, CI, slower machines).
public actor PriceActor {
    // Last accepted timestamp per symbol for out-of-order filtering
    private var lastProcessedTimestamps: [String: Int64] = [:]

    // Last accepted timestamp per symbol for throttle gate
    private var lastAcceptedTimestamps: [String: Int64] = [:]

    // Minimum interval between accepted ticks (in milliseconds)
    private let minInterval: Int64

    /// Initializes the PriceActor with a specific throttling rate.
    /// - Parameter updatesPerSecond: The maximum number of updates allowed per second (default is 10Hz).
    public init(updatesPerSecond: Int = 10) {
        // 10Hz → 100ms minimum interval between accepted ticks
        self.minInterval = Int64(1000 / updatesPerSecond)
    }

    /// Processes a single tick, returning the tick if it passes both the
    /// out-of-order guard and the throttle gate. Otherwise returns nil.
    public func process(next tick: KlineTick) -> KlineTick? {
        let symbol = tick.symbol

        // MARK: 1. Out-of-Order Guard (per symbol)
        // Drop any tick whose timestamp is not newer than the last processed one.
        let lastTimestamp = lastProcessedTimestamps[symbol, default: -1]
        guard tick.eventTime > lastTimestamp else {
            return nil
        }
        lastProcessedTimestamps[symbol] = tick.eventTime

        // MARK: 2. Timestamp-Based Throttle Gate (per symbol)
        // Use the tick's own timestamp so the result is deterministic
        // regardless of real wall-clock execution speed (critical for CI stability).
        if let lastAccepted = lastAcceptedTimestamps[symbol] {
            if tick.eventTime - lastAccepted < minInterval {
                return nil // Too soon — throttle this update
            }
        }

        lastAcceptedTimestamps[symbol] = tick.eventTime
        return tick
    }
}
