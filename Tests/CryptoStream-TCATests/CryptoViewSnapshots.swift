import XCTest
import SwiftUI
import SnapshotTesting
import ComposableArchitecture
@testable import CryptoStream_TCA

// MARK: - Snapshot Tests for CryptoView (Visual Regression Guard)
//
// 🎯 目的：確保 Glassmorphism UI 在每次代碼變動後視覺上不會發生意外退化。
//
// 📸 使用方式（兩步驟設定）：
//   步驟一：在本地 Xcode 按 Cmd+U 執行一次（isRecording = true 時會「失敗」並生成參考圖）
//   步驟二：將生成的 __Snapshots__ 資料夾 git add & git push 後，CI 就能正常比對
//
// ⚠️ CI 注意：CI 首次跑到這個測試前，必須先有本地生成的參考圖才能成功。

@MainActor
final class CryptoViewSnapshotTests: XCTestCase {

    // 👇 首次在本地執行時，設為 true 生成參考圖；生成後改回 false
    let record = false

    // macOS 環境下使用的 Sparkline 渲染尺寸
    private let snapshotSize = CGSize(width: 393, height: 852)

    // ── 1. 初始連線中狀態 ────────────────────────────────────────────
    func testConnectingState() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .connecting
        assertSnapshot(
            of: makeHostingController(state: state),
            as: .image(size: snapshotSize),
            record: record
        )
    }

    // ── 2. 已連線並載入真實價格 ──────────────────────────────────────
    func testConnectedWithPrices() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .connected
        state.coins[id: "btcusdt"]?.currentPrice = 67_432.50
        state.coins[id: "btcusdt"]?.priceColor = .green
        state.coins[id: "ethusdt"]?.currentPrice = 3_215.78
        state.coins[id: "ethusdt"]?.priceColor = .green
        state.coins[id: "solusdt"]?.currentPrice = 148.30
        state.coins[id: "solusdt"]?.priceColor = .red
        state.coins[id: "bnbusdt"]?.currentPrice = 602.40
        state.coins[id: "bnbusdt"]?.priceColor = .primary
        state.coins[id: "dogeusdt"]?.currentPrice = 0.1587
        state.coins[id: "dogeusdt"]?.priceColor = .red
        assertSnapshot(
            of: makeHostingController(state: state),
            as: .image(size: snapshotSize),
            record: record
        )
    }

    // ── 3. 全幣種大漲行情 ────────────────────────────────────────────
    func testAllPricesSurging() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .connected
        state.coins[id: "btcusdt"]?.currentPrice = 70_000.00
        state.coins[id: "btcusdt"]?.priceColor = .green
        state.coins[id: "ethusdt"]?.currentPrice = 4_000.00
        state.coins[id: "ethusdt"]?.priceColor = .green
        state.coins[id: "solusdt"]?.currentPrice = 200.00
        state.coins[id: "solusdt"]?.priceColor = .green
        state.coins[id: "bnbusdt"]?.currentPrice = 700.00
        state.coins[id: "bnbusdt"]?.priceColor = .green
        state.coins[id: "dogeusdt"]?.currentPrice = 0.25
        state.coins[id: "dogeusdt"]?.priceColor = .green
        assertSnapshot(
            of: makeHostingController(state: state),
            as: .image(size: snapshotSize),
            record: record
        )
    }

    // ── 4. 斷線狀態 ──────────────────────────────────────────────────
    func testDisconnectedState() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .disconnected
        state.coins[id: "btcusdt"]?.currentPrice = 65_000.00
        state.coins[id: "ethusdt"]?.currentPrice = 3_100.00
        state.coins[id: "solusdt"]?.currentPrice = 130.00
        assertSnapshot(
            of: makeHostingController(state: state),
            as: .image(size: snapshotSize),
            record: record
        )
    }

    // ── 5. 空值初始狀態 ──────────────────────────────────────────────
    func testInitialEmptyState() {
        let state = CryptoReducer.State()
        assertSnapshot(
            of: makeHostingController(state: state),
            as: .image(size: snapshotSize),
            record: record
        )
    }

    // MARK: - Helpers

    private func makeHostingController(state: CryptoReducer.State) -> NSViewController {
        // 明確指定泛型型別，修復 CI 的型別推斷錯誤
        let store = Store<CryptoReducer.State, CryptoReducer.Action>(
            initialState: state
        ) {
            // 使用空 Reducer 避免 Side Effects（WebSocket）影響快照穩定性
            CryptoReducer()
        } withDependencies: {
            // 在測試中，connect 永遠返回一個不會產生訊息的空 Stream
            $0.webSocketClient.connect = { _ in
                AsyncThrowingStream { _ in }
            }
            $0.webSocketClient.disconnect = {}
        }
        let rootView = CryptoView(store: store).preferredColorScheme(.dark)
        return NSHostingController(rootView: rootView)
    }
}
