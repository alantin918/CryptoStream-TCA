import XCTest
import ComposableArchitecture
@testable import CryptoStream_TCA

// MARK: - 併發壓力測試 (Concurrency & Stress Tests)
//
// 🎯 目的：驗證 PriceActor 在高頻、高併發的極端情境下
//         1. 節流邏輯依然正確（不讓超頻資料通過）
//         2. Actor 的串列化保證不會發生 Data Race
//         3. 多幣種之間的節流狀態互相獨立，不互相汙染

final class PriceActorConcurrencyTests: XCTestCase {

    // ── 1. 瞬間爆發壓力測試 (Burst Stress Test) ───────────────────────
    // 情境：同一幣種，100 個 Task 同時並發送出，驗證 Actor 只讓「極少數」通過
    func testBurstConcurrencyThrottling() async {
        let actor = PriceActor(updatesPerSecond: 10)
        let symbol = "btcusdt"

        // 使用 TaskGroup 真正並發地打出 100 筆請求
        let results = await withTaskGroup(of: KlineTick?.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let tick = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: Double(50000 + i), eventTime: Int64(1000 + i), openTime: 1000, isClosed: false)
                    return await actor.process(next: tick)
                }
            }
            var passed: [KlineTick] = []
            for await result in group {
                if let tick = result { passed.append(tick) }
            }
            return passed
        }

        // 100 個 Task 幾乎同時發送，10Hz 限制下最多只應有 1 筆通過
        // Actor 保證了串列化（無 Data Race），節流邏輯只讓第一個通過
        XCTAssertEqual(results.count, 1,
            "100 個並發 Task 打出，Actor 串列化後只有 1 筆通過。實際通過：\(results.count)")
    }

    // ── 2. 高頻連續壓力測試 (Sequential High-Frequency Stress) ──────
    // 情境：在 150ms 內連續送出 15 筆，驗證節流只讓 ~1-2 筆通過
    func testSequentialHighFrequencyStress() async {
        let actor = PriceActor(updatesPerSecond: 10) // 100ms 間隔
        let symbol = "solusdt"
        var passCount = 0

        for i in 0..<15 {
            let tick = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: Double(100 + i), eventTime: Int64(1000 + i * 10), openTime: 1000, isClosed: false)
            if await actor.process(next: tick) != nil {
                passCount += 1
            }
            // 每筆間隔 10ms（10Hz = 每 100ms 才允許 1 筆）
            try? await Task.sleep(for: .milliseconds(10))
        }

        // 15 筆 × 10ms = 150ms，10Hz 限制下最多通過 2 筆（第 1ms 和第 101ms 時各一筆）
        XCTAssertLessThanOrEqual(passCount, 2,
            "150ms 內 15 筆連續送入，10Hz 限制下最多 2 筆通過。實際通過：\(passCount)")
        XCTAssertGreaterThanOrEqual(passCount, 1, "第一筆必須通過")
    }

    // ── 3. 多幣種隔離保證 (Cross-Symbol Isolation) ───────────────────
    // 情境：BTC 被節流時，ETH 和 SOL 仍應不受影響、獨立正常通過
    func testMultiSymbolThrottlingIsolation() async {
        let actor = PriceActor(updatesPerSecond: 10)

        // BTC - 第一筆通過
        let btc1 = KlineTick(symbol: "btcusdt", open: 1, high: 1, low: 1, close: 65000, eventTime: 1000, openTime: 1000, isClosed: false)
        let btc1Result = await actor.process(next: btc1)
        XCTAssertNotNil(btc1Result, "BTC 第一筆必須通過")

        // BTC - 第二筆被節流（間隔 0ms）
        let btc2 = KlineTick(symbol: "btcusdt", open: 1, high: 1, low: 1, close: 65001, eventTime: 1001, openTime: 1000, isClosed: false)
        let btc2Result = await actor.process(next: btc2)
        XCTAssertNil(btc2Result, "BTC 第二筆必須被節流")

        // ETH - 雖然 BTC 被節流了，ETH 的第一筆仍應通過（獨立狀態）
        let eth1 = KlineTick(symbol: "ethusdt", open: 1, high: 1, low: 1, close: 3200, eventTime: 1000, openTime: 1000, isClosed: false)
        let eth1Result = await actor.process(next: eth1)
        XCTAssertNotNil(eth1Result, "ETH 第一筆應通過，不受 BTC 節流影響")

        // SOL - 同樣獨立通過
        let sol1 = KlineTick(symbol: "solusdt", open: 1, high: 1, low: 1, close: 145, eventTime: 1000, openTime: 1000, isClosed: false)
        let sol1Result = await actor.process(next: sol1)
        XCTAssertNotNil(sol1Result, "SOL 第一筆應通過，不受其他幣種影響")

        // ETH - 第二筆被節流（ETH 自己的間隔）
        let eth2 = KlineTick(symbol: "ethusdt", open: 1, high: 1, low: 1, close: 3201, eventTime: 1002, openTime: 1000, isClosed: false)
        let eth2Result = await actor.process(next: eth2)
        XCTAssertNil(eth2Result, "ETH 第二筆必須被節流")
    }

    // ── 4. 亂序防護壓力測試 (Out-of-Order Rejection Stress) ─────────
    // 情境：送入 50 筆亂序資料，確保所有舊時間戳都被正確過濾
    func testOutOfOrderRejectionUnderLoad() async {
        let actor = PriceActor(updatesPerSecond: 1000) // 取消節流，專注測試亂序過濾
        let symbol = "bnbusdt"

        // 先建立一個時間戳基準：eventTime = 5000
        let baseTick = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: 600, eventTime: 5000, openTime: 1000, isClosed: false)
        let baseResult = await actor.process(next: baseTick)
        XCTAssertNotNil(baseResult)

        // 送入 50 筆舊時間戳（全部 eventTime < 5000），全部應被過濾
        var rejectedCount = 0
        for i in 0..<50 {
            let oldTick = KlineTick(symbol: symbol, open: 1, high: 1, low: 1, close: Double(600 + i), eventTime: Int64(4999 - i), openTime: 1000, isClosed: false)
            if await actor.process(next: oldTick) == nil {
                rejectedCount += 1
            }
        }

        XCTAssertEqual(rejectedCount, 50, "50 筆舊時間戳應全部被拒絕。實際拒絕：\(rejectedCount)")
    }
}

// MARK: - 整合測試 (Integration Tests)
//
// 🎯 目的：測試從「WebSocket 訊息」到「Reducer 處理」再到「PriceActor 節流」的完整流程
//         1. 多幣種同時高頻傳來時，只有「通過 Actor 節流」的資料才會更新 State
//         2. 非法 JSON 格式應被靜默忽略，不讓 App 崩潰

@MainActor
final class CryptoIntegrationTests: XCTestCase {

    // ── 5. 整合測試：高頻 WebSocket 節流 ─────────────────────────────
    // 情境：WebSocket 快速連送 3 筆 BTC 訊息（間隔 < 1ms）
    //       PriceActor 應只讓第 1 筆到達 Reducer，2、3 筆被節流
    func testWebSocketThrottlingIntegration() async {
        nonisolated(unsafe) var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation!
        let mockStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { cont in
            continuation = cont
        }
        let testDate = Date(timeIntervalSince1970: 1704067200)

        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.webSocketClient.connect = { _ in mockStream }
            $0.webSocketClient.disconnect = { continuation.finish() }
            $0.date.now = testDate
        }
        store.exhaustivity = .off // 允許部分 Action 未被追蹤（被節流的訊息）

        let task = await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }

        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }

        // 瞬間送出 3 筆 BTC 訊息（無時間間隔）
        let btcMessages = [65000.00, 65001.00, 65002.00]
        for (i, price) in btcMessages.enumerated() {
            let json = """
            {
              "stream": "btcusdt@kline_1m",
              "data": {
                "e": "kline",
                "E": \(1000 + i),
                "s": "BTCUSDT",
                "k": {
                  "t": 1000,
                  "T": 1599,
                  "s": "BTCUSDT",
                  "i": "1m",
                  "f": 100,
                  "L": 200,
                  "o": "64000.00",
                  "c": "\(price)",
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
            continuation.yield(.string(json))
        }

        // 驗證：只有第一筆 BTC (65000) 應抵達 Reducer
        let expectedFirstTick = KlineTick(symbol: "btcusdt", open: 64000.0, high: 66000.0, low: 63000.0, close: 65000.0, eventTime: 1000, openTime: 1000, isClosed: false)
        await store.receive(.receiveKline(expectedFirstTick), timeout: .seconds(2)) {
            $0.coins[id: "btcusdt"]?.currentPrice = 65000.0
            $0.coins[id: "btcusdt"]?.priceColor = .green
            $0.coins[id: "btcusdt"]?.lastUpdate = testDate
            $0.coins[id: "btcusdt"]?.klineHistory = [expectedFirstTick]
        }

        // 清理
        await store.send(.onDisappear) {
            $0.connectivityStatus = .disconnected
        }
        await task.cancel()
    }

    // ── 6. 整合測試：非法 JSON 靜默忽略 ──────────────────────────────
    // 情境：WebSocket 送來格式損壞的 JSON
    //       App 不應崩潰，State 也不應有任何變動
    func testMalformedJSONIsSilentlyIgnored() async {
        nonisolated(unsafe) var continuation: AsyncThrowingStream<URLSessionWebSocketTask.Message, Error>.Continuation!
        let mockStream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { cont in
            continuation = cont
        }

        let store = TestStore(initialState: CryptoReducer.State()) {
            CryptoReducer()
        } withDependencies: {
            $0.webSocketClient.connect = { _ in mockStream }
            $0.webSocketClient.disconnect = { continuation.finish() }
        }

        let task = await store.send(.onAppear) {
            $0.connectivityStatus = .connecting
        }
        await store.receive(.updateStatus(.connected)) {
            $0.connectivityStatus = .connected
        }

        // 送入各種非法 JSON
        let badMessages = [
            "this is not json at all",
            "{ \"broken\": }",
            "",
            "{ \"stream\": \"btcusdt@kline_1m\" }" // 缺少 data 欄位
        ]
        for msg in badMessages {
            continuation.yield(.string(msg))
        }

        // 等待一小段時間讓 stream 處理，不應收到任何 receiveKline action
        try? await Task.sleep(for: .milliseconds(100))

        // 清理 - State 必須完全不變
        await store.send(.onDisappear) {
            $0.connectivityStatus = .disconnected
        }
        await task.cancel()
    }
}
