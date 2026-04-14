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
        }
        
        // 2. BTC Price goes up
        let higherBtc = PriceTick(symbol: "btcusdt", price: 50100.0, timestamp: 1001)
        await store.send(.receivePrice(higherBtc)) {
            $0.coins[id: "btcusdt"]?.lastPrice = 50000.0
            $0.coins[id: "btcusdt"]?.currentPrice = 50100.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
        }
        
        // 3. Receive ETH Price independently
        let ethPrice = PriceTick(symbol: "ethusdt", price: 2500.0, timestamp: 1000)
        await store.send(.receivePrice(ethPrice)) {
            $0.coins[id: "ethusdt"]?.currentPrice = 2500.0
            $0.coins[id: "ethusdt"]?.priceColor = .primary
            $0.coins[id: "ethusdt"]?.lastUpdate = testDate
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
        }
        
        await store.send(.onDisappear) {
            $0.connectivityStatus = .disconnected
        }
        
        await task.cancel()
    }
}

final class PriceActorTests: XCTestCase {
    
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
