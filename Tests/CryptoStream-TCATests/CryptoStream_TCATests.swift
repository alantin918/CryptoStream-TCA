import XCTest
import ComposableArchitecture
@testable import CryptoStream_TCA

@MainActor
final class CryptoReducerTests: XCTestCase {
    
    func testReceiveKlineDeltaColoring() async {
        let testDate = Date(timeIntervalSince1970: 1234567890)
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.date.now = testDate
        }
        
        let btcKline1 = KlineTick(symbol: "btcusdt", open: 50000.0, high: 50500.0, low: 49500.0, close: 50000.0, eventTime: 1000, openTime: 1000, isClosed: false)
        
        // 1. Receive BTC Kline (Open = Close -> Color should be green as close >= open)
        await store.send(.receiveKline(btcKline1)) {
            $0.coins[id: "btcusdt"]?.currentPrice = 50000.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.klineHistory = [btcKline1]
            $0.coins[id: "btcusdt"]?.sparklineBuffer = [btcKline1.close]
        }
        
        // 2. BTC Kline updates within same minute (Price goes up)
        let higherBtc = KlineTick(symbol: "btcusdt", open: 50000.0, high: 50500.0, low: 49500.0, close: 50100.0, eventTime: 1001, openTime: 1000, isClosed: false)
        await store.send(.receiveKline(higherBtc)) {
            $0.coins[id: "btcusdt"]?.lastPrice = 50000.0
            $0.coins[id: "btcusdt"]?.currentPrice = 50100.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.klineHistory = [higherBtc] // Replaces previous
            $0.coins[id: "btcusdt"]?.sparklineBuffer = [btcKline1.close, higherBtc.close]
        }
        
        // 3. Receive new ETH Kline (Price goes down: Open > Close)
        let ethKline = KlineTick(symbol: "ethusdt", open: 2600.0, high: 2600.0, low: 2400.0, close: 2500.0, eventTime: 1000, openTime: 2000, isClosed: false)
        await store.send(.receiveKline(ethKline)) {
            $0.coins[id: "ethusdt"]?.currentPrice = 2500.0
            $0.coins[id: "ethusdt"]?.priceColor = .red
            $0.coins[id: "ethusdt"]?.lastUpdate = testDate
            $0.coins[id: "ethusdt"]?.klineHistory = [ethKline]
            $0.coins[id: "ethusdt"]?.sparklineBuffer = [ethKline.close]
        }
    }
    
    func testConnectionLifecycle() async {
        let testDate = Date(timeIntervalSince1970: 1672515782)
        nonisolated(unsafe) var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation!
        let mockStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { cont in
            continuation = cont
        }
        
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.webSocketClient.connect = { (_: URL) in mockStream }
            $0.webSocketClient.disconnect = { continuation.finish() }
            $0.date.now = testDate
        }
        
        let task = await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }
        
        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }
        
        // Mock Enveloped Binance Kline Message
        let jsonString = """
        {
          "stream": "btcusdt@kline_1m",
          "data": {
            "e": "kline",
            "E": 1672515782136,
            "s": "BTCUSDT",
            "k": {
              "t": 1672515780000,
              "T": 1672515839999,
              "s": "BTCUSDT",
              "i": "1m",
              "f": 100,
              "L": 200,
              "o": "64000.00",
              "c": "65000.00",
              "h": "66000.00",
              "l": "63000.00",
              "v": "1000",
              "n": 100,
              "x": false,
              "q": "1.0000",
              "V": "500",
              "Q": "0.500",
              "B": "123456"
            }
          }
        }
        """
        continuation.yield(.string(jsonString))
        
        let expectedKline = KlineTick(
            symbol: "btcusdt",
            open: 64000.0,
            high: 66000.0,
            low: 63000.0,
            close: 65000.0,
            eventTime: 1672515782136,
            openTime: 1672515780000,
            isClosed: false
        )
        
        await store.receive(.receiveKline(expectedKline)) {
            $0.coins[id: "btcusdt"]?.currentPrice = 65000.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.klineHistory = [expectedKline]
            $0.coins[id: "btcusdt"]?.sparklineBuffer = [expectedKline.close]
        }
        
        await store.send(.onDisappear) {
            $0.connectivityStatus = .disconnected
        }
        
        await task.cancel()
    }
    
    // MARK: - 3. 測試錯誤恢復 (Error Recovery)
    
    func testWebSocketErrorHandling() async {
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.webSocketClient.connect = { (_: URL) in
                throw URLError(.notConnectedToInternet)
            }
            $0.webSocketClient.disconnect = {}
        }
        
        await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }
        
        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }
        
        await store.receive(.updateStatus(.disconnected)) {
            $0.connectivityStatus = .disconnected
        }
    }
    
    // MARK: - 4. 測試未知幣種過濾 (Filtering Unknown Symbols)
    
    func testUnknownSymbolFiltering() async {
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        }
        
        let unknownKline = KlineTick(symbol: "SHIBUSDT", open: 0.1, high: 0.2, low: 0.1, close: 0.15, eventTime: 1000, openTime: 1000, isClosed: false)
        
        await store.send(.receiveKline(unknownKline))
    }
}

final class PriceActorTests: XCTestCase {
    
    // MARK: - 5. 測試節流速率 (Throttling Rate Limit)
    
    func testThrottlingRateLimit() async {
        let actor = PriceActor(updatesPerSecond: 10)
        let symbol = "BTC"

        let tick1 = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: 100.0, eventTime: 1000, openTime: 1000, isClosed: false)
        let tick2 = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: 101.0, eventTime: 1001, openTime: 1000, isClosed: false)  // 1ms 後，太近
        let tick3 = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: 102.0, eventTime: 1101, openTime: 1000, isClosed: false)  // 101ms 後，應過關

        var result = await actor.process(next: tick1)
        XCTAssertNotNil(result)

        result = await actor.process(next: tick2)
        XCTAssertNil(result, "間隔 1ms < 100ms，必須被節流攔截")

        result = await actor.process(next: tick3)
        XCTAssertNotNil(result, "間隔 101ms ≥ 100ms，應允許通過")
    }
    
    func testMultiSymbolProcessing() async {
        let actor = PriceActor(updatesPerSecond: 1000)
        
        let btc1 = KlineTick(symbol: "BTC", open: 1, high: 1, low: 1, close: 100.0, eventTime: 1000, openTime: 1000, isClosed: false)
        let eth1 = KlineTick(symbol: "ETH", open: 1, high: 1, low: 1, close: 50.0, eventTime: 1000, openTime: 1000, isClosed: false)
        let btcOld = KlineTick(symbol: "BTC", open: 1, high: 1, low: 1, close: 90.0, eventTime: 999, openTime: 1000, isClosed: false)
        
        var result = await actor.process(next: btc1)
        XCTAssertEqual(result, btc1)
        
        result = await actor.process(next: eth1)
        XCTAssertEqual(result, eth1)
        
        result = await actor.process(next: btcOld)
        XCTAssertNil(result)
    }
}
