import XCTest
import ComposableArchitecture
@testable import CryptoStream_TCA

@MainActor
final class CryptoReducerTests: XCTestCase {
    
    func testReceivePriceDeltaColoring() async {
        let testDate = Date(timeIntervalSince1970: 1234567890)
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.date.now = testDate
        }
        
        let btcPrice = PriceTick(symbol: "btcusdt", price: 50000.0, timestamp: 1000)
        
        // 1. Receive BTC Price
        await store.send(.receivePrice(btcPrice)) {
            $0.coins[id: "btcusdt"]?.currentPrice = 50000.0
            $0.coins[id: "btcusdt"]?.priceColor = .primary
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.priceHistory = [50000.0]
        }
        
        // 2. BTC Price goes up
        let higherBtc = PriceTick(symbol: "btcusdt", price: 50100.0, timestamp: 1001)
        await store.send(.receivePrice(higherBtc)) {
            $0.coins[id: "btcusdt"]?.lastPrice = 50000.0
            $0.coins[id: "btcusdt"]?.currentPrice = 50100.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.priceHistory = [50000.0, 50100.0]
        }
        
        // 3. Receive ETH Price independently
        let ethPrice = PriceTick(symbol: "ethusdt", price: 2500.0, timestamp: 1000)
        await store.send(.receivePrice(ethPrice)) {
            $0.coins[id: "ethusdt"]?.currentPrice = 2500.0
            $0.coins[id: "ethusdt"]?.priceColor = .primary
            $0.coins[id: "ethusdt"]?.lastUpdate = testDate
            $0.coins[id: "ethusdt"]?.priceHistory = [2500.0]
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
        
        // Mock Enveloped Binance Message
        let jsonString = """
        {
          "stream": "btcusdt@trade",
          "data": {
            "e": "trade",
            "E": 1672515782136,
            "s": "BTCUSDT",
            "p": "65000.00"
          }
        }
        """
        continuation.yield(.string(jsonString))
        
        let expectedPrice = PriceTick(symbol: "btcusdt", price: 65000.0, timestamp: 1672515782136)
        await store.receive(.receivePrice(expectedPrice)) {
            $0.coins[id: "btcusdt"]?.currentPrice = 65000.0
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.priceHistory = [65000.0]
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
            // 模擬連線後立即拋出錯誤
            $0.webSocketClient.connect = { (_: URL) in
                throw URLError(.notConnectedToInternet)
            }
            $0.webSocketClient.disconnect = {}
        }
        
        // 動作：嘗試開始連線
        await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }
        
        // 驗證：由於邏輯順序，會先設為 connected
        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }
        
        // 驗證：隨後拋出錯誤，切換為 disconnected
        await store.receive(.updateStatus(.disconnected)) {
            $0.connectivityStatus = .disconnected
        }
    }
    
    // MARK: - 4. 測試未知幣種過濾 (Filtering Unknown Symbols)
    
    func testUnknownSymbolFiltering() async {
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        }
        
        // 傳來一個不在預設清單 (BTC, ETH, SOL, BNB, DOGE) 中的幣種
        let unknownPrice = PriceTick(symbol: "SHIBUSDT", price: 0.00001, timestamp: 1000)
        
        // 動作：接收到未知幣種
        await store.send(.receivePrice(unknownPrice))
        
        // 驗證：State 應該沒有任何改變（因為 guard 會擋掉）
        // 如果 State 發生任何變動，TestStore 會報錯
    }
}

final class PriceActorTests: XCTestCase {
    
    // MARK: - 5. 測試節流速率 (Throttling Rate Limit)
    
    func testThrottlingRateLimit() async {
        // 設定 10Hz = 每 100ms 只能通關一筆
        let actor = PriceActor(updatesPerSecond: 10)
        let symbol = "BTC"
        
        let tick1 = PriceTick(symbol: symbol, price: 100.0, timestamp: 1000)
        let tick2 = PriceTick(symbol: symbol, price: 101.0, timestamp: 1001) // 太頻繁
        let tick3 = PriceTick(symbol: symbol, price: 102.0, timestamp: 1101) // 101ms 後，應過關
        
        // 第一筆：必過
        var result = await actor.process(next: tick1)
        XCTAssertNotNil(result)
        
        // 第二筆：只過了 1ms，應該被攔截
        result = await actor.process(next: tick2)
        XCTAssertNil(result, "1ms 的間隔太短，必須被節流攔截")
        
        // 模擬等待 105ms (超過 100ms)
        try? await Task.sleep(for: .milliseconds(105))
        
        // 第三筆：已經超過 100ms 間隔，應該過關
        result = await actor.process(next: tick3)
        XCTAssertNotNil(result, "超過 100ms 後，應該允許下一筆資料通過")
    }
    
    func testMultiSymbolProcessing() async {
        let actor = PriceActor(updatesPerSecond: 1000)
        
        let btc1 = PriceTick(symbol: "BTC", price: 100.0, timestamp: 1000)
        let eth1 = PriceTick(symbol: "ETH", price: 50.0, timestamp: 1000)
        let btcOld = PriceTick(symbol: "BTC", price: 90.0, timestamp: 999)
        
        // BTC 1 passes
        var result = await actor.process(next: btc1)
        XCTAssertEqual(result, btc1)
        
        // ETH 1 passes (different symbol, independent)
        result = await actor.process(next: eth1)
        XCTAssertEqual(result, eth1)
        
        // BTC Old is dropped
        result = await actor.process(next: btcOld)
        XCTAssertNil(result)
    }
}
