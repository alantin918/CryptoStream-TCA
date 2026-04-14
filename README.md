# CryptoStream-TCA

基於 **The Composable Architecture (TCA)** 與 **Clean Architecture** 實作的加密貨幣即時報價範例專案。

## 專案功能與技術特性

*   **架構分層**：採用 Clean Architecture 原則，劃分 Domain、Clients 與 Features，降低各模組間的耦合度。
*   **即時資料串接**：透過 `URLSessionWebSocketTask` 介接 Binance WebSocket (BTC/USDT 交易對)。
*   **並發安全管理**：使用 Swift Actor 實作 `PriceActor`，處理高頻資料的節流 (Throttling) 與亂序過濾，確保 UI 更新頻率穩定。
*   **使用者介面**：使用 SwiftUI 實作，包含基本的連線狀態指示與價格漲跌變色動畫。
*   **單元測試**：包含針對 Reducer 狀態流與 Actor 過濾邏輯的測試案例。

## 使用技術

*   **語言**: Swift 6
*   **框架**: SwiftUI, Composable Architecture (TCA 1.0.0)
*   **連線協定**: WebSocket
*   **測試工具**: XCTest

## 目錄結構

```text
Sources/
├── Domain/           # 業務模型與 Actor 邏輯
├── Clients/          # 網路連線實作 (WebSocketClient)
└── Features/         # UI 視圖與 Reducer 邏輯
Tests/                # 單元測試程式碼
```

## 如何運行

1.  開啟 `CryptoApp.xcodeproj`。
2.  選擇目標設備（建議使用 iOS 16 以上版本）。
3.  執行專案即可自動連線並顯示即時報價。

## 運行測試

在 Xcode 中點擊 `Product` -> `Test` 或使用快捷鍵 `Cmd + U`。
