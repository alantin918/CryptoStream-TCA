import XCTest
import SwiftUI
import SnapshotTesting
import ComposableArchitecture
@testable import CryptoStream_TCA

// MARK: - Snapshot Tests for CryptoView (Visual Regression Guard)
//
// 🎯 目的：確保 Glassmorphism UI 在每次代碼變動後視覺上不會發生意外退化。
//
// 📸 使用方式：
//   - 第一次執行：測試會「失敗」並在 __Snapshots__ 資料夾下生成參考圖（此為正常行為）。
//   - 往後執行：自動將目前畫面與參考圖做像素級比對。
//   - 需要重新錄製：將 `isRecording = true` 取消註解並執行一次，之後再改回 false。
//
// ⚠️ 環境注意：參考圖以 macOS 環境為主，與 CI 環境保持一致。

@MainActor
final class CryptoViewSnapshotTests: XCTestCase {

    // ── 1. 初始連線中狀態 ─────────────────────────────────────────────
    // 驗證：黃色燈號 + 所有幣種顯示「---.---」佔位符
    func testConnectingState() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .connecting

        let view = makeView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    // ── 2. 已連線並載入真實價格 ───────────────────────────────────────
    // 驗證：綠色燈號 + 5 種幣種的價格正確顯示
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

        let view = makeView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    // ── 3. 價格上漲閃爍視覺 (Price Surge) ────────────────────────────
    // 驗證：所有幣種同時顯示綠色（大漲行情）
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

        let view = makeView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    // ── 4. 斷線狀態 ───────────────────────────────────────────────────
    // 驗證：紅色燈號 + 最後已知的價格數字仍然顯示（不清空）
    func testDisconnectedState() {
        var state = CryptoReducer.State()
        state.connectivityStatus = .disconnected

        // 斷線後仍應保留最後一次的价格資料
        state.coins[id: "btcusdt"]?.currentPrice = 65_000.00
        state.coins[id: "ethusdt"]?.currentPrice = 3_100.00
        state.coins[id: "solusdt"]?.currentPrice = 130.00

        let view = makeView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    // ── 5. 空值初始狀態（無任何價格） ────────────────────────────────
    // 驗證：所有幣種顯示「---.---」佔位符，且 UI 不崩潰
    func testInitialEmptyState() {
        let state = CryptoReducer.State()
        let view = makeView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 393, height: 852)))
    }

    // MARK: - Helpers

    private func makeView(state: CryptoReducer.State) -> some View {
        let store = Store(initialState: state) {
            // 使用空 Reducer，避免 Side Effects 影響快照的穩定性
            EmptyReducer()
        }
        return CryptoView(store: store)
            .preferredColorScheme(.dark)
    }
}
