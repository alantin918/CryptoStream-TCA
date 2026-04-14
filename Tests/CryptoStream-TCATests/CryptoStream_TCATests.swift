import XCTest
import ComposableArchitecture
@testable import CryptoStream_TCA

@MainActor
final class CryptoReducerTests: XCTestCase {
    
    // MARK: - 1. 測試價格紅綠色邏輯 (Price Delta Validation)
    
    func testReceivePriceDeltaColoring() async {
        // 使用 block-based 初始化，解決 TCA 1.17.0 的型別推斷問題
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        }
        
        // 第 1 筆價格：預設顏色
        let firstPrice = CryptoPrice(symbol: "BTCUSDT", price: 50000.0, timestamp: 1000)
        await store.send(.receivePrice(firstPrice)) {
            $0.currentPrice = firstPrice
            $0.priceColor = .primary // 初次無舊價可比，保持原廠顏色
        }
        
        // 第 2 筆價格：漲了 100 塊，應該變綠燈
        let higherPrice = CryptoPrice(symbol: "BTCUSDT", price: 50100.0, timestamp: 1001)
        await store.send(.receivePrice(higherPrice)) {
            $0.currentPrice = higherPrice
            $0.priceColor = .green
        }
        
        // 第 3 筆價格：暴跌，應該變紅燈
        let lowerPrice = CryptoPrice(symbol: "BTCUSDT", price: 49000.0, timestamp: 1002)
        await store.send(.receivePrice(lowerPrice)) {
            $0.currentPrice = lowerPrice
            $0.priceColor = .red
        }
    }
    
    // MARK: - 2. 測試生命週期與 WebSocket 依賴 (Lifecycle & Side Effects)
    
    func testConnectionLifecycle() async {
        // 利用 Swift 內建的 AsyncStream 來模擬虛擬的假 Socket 連線
        // nonisolated(unsafe) 是 Swift 6 中允許在並發環境捕獲可變變數的標準做法
        nonisolated(unsafe) var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation!
        let mockStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { cont in
            continuation = cont
        }
        
        // 使用 withDependencies 閉包注入假依賴，這是 TCA 1.17.0 最穩定的寫法
        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            // 注意：明確標注參數型別 (_ url: URL) 解決 Swift 6 推斷問題
            $0.webSocketClient.connect = { (_: URL) in mockStream }
            $0.webSocketClient.disconnect = { continuation.finish() }
        }
        
        // 【動作】畫面出現：狀態應變成 connecting，然後 effect .run 裡發送 connected
        let task = await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }
        
        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }
        
        // 【動作】後端 WebSocket 傳來合乎 API 規範的 JSON 假資料
        let jsonString = """
        {
          "e": "trade",
          "E": 1672515782136,
          "s": "BTCUSDT",
          "p": "65000.00"
        }
        """
        continuation.yield(.string(jsonString))
        
        // 驗證 Reducer 是否真的正確解碼，並最終拋出這筆新的價格事件
        let expectedPrice = CryptoPrice(symbol: "BTCUSDT", price: 65000.0, timestamp: 1672515782136)
        await store.receive(.receivePrice(expectedPrice)) {
            $0.currentPrice = expectedPrice
        }
        
        // 【動作】畫面從螢幕消失：觸發斷線狀態
        await store.send(.onDisappear) {
            $0.connectivityStatus = .disconnected
        }
        
        // 強制中斷這個虛擬的無盡任務
        await task.cancel()
    }
}

// MARK: - 3. 專屬 Actor 防禦網測試

final class PriceActorTests: XCTestCase {
    
    func testOutOfOrderDataIsDropped() async {
        // 初始化 Actor，這裡頻率設定超高，避免被節流擋下（專注測亂序）
        let actor = PriceActor(updatesPerSecond: 1000)
        
        let tick1 = CryptoPrice(symbol: "BTC", price: 100.0, timestamp: 1000)
        let tickOutdated = CryptoPrice(symbol: "BTC", price: 90.0, timestamp: 999) // 過期無效封包
        let tick2 = CryptoPrice(symbol: "BTC", price: 105.0, timestamp: 1001)
        
        // 第一筆正常過關
        var result = await actor.process(next: tick1)
        XCTAssertEqual(result, tick1)
        
        // 塞入過去的時間戳 -> 被 Actor 中的機制精準攔截拋棄
        result = await actor.process(next: tickOutdated)
        XCTAssertNil(result, "Timestamp 歷史封包必須被自動拋棄，不能干擾 UI")
        
        // 等待超過節流間隔 (1000Hz = 1ms)，確保下一筆資料不會被節流擋下
        try? await Task.sleep(for: .milliseconds(5))
        
        // 較新的封包正常過關
        result = await actor.process(next: tick2)
        XCTAssertEqual(result, tick2)
    }
}
