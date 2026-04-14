# CryptoStream-TCA

一個基於 **The Composable Architecture (TCA)** 與 **Clean Architecture** 打造的高效能加密貨幣即時報價 App。

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg) 
![TCA](https://img.shields.io/badge/Architecture-TCA-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey.svg)

## 🚀 專案亮點

*   **頂級架構設計**：嚴格遵守 Clean Architecture 原則，將 Domain (業務邏輯)、Feature (UI 狀態) 與 Client (底層依賴) 徹底解耦。
*   **高頻資料處理**：專為 Binance WebSocket 設計，支援高頻（10Hz+）成交資料流。
*   **執行緒安全 (Swift 6 Actor)**：利用 `PriceActor` 進行資料節流與亂序過濾，保證 UI 渲染不掉幀、不卡頓，杜絕 Data Race。
*   **現代化 UI 體驗**：
    *   **Glassmorphism (毛玻璃)**：採用 `.ultraThinMaterial` 打造懸浮質感。
    *   **動態微動畫**：價格異動時伴隨脈搏閃擊特效 (Pulse Glow)。
    *   **呼吸燈連線指示器**：即時回饋 WebSocket 连接狀態。
*   **完整測試覆蓋**：包含對 Reducer 狀態流的 `TestStore` 測試，以及針對 Actor 防禦機制的單元測試。

## 🛠 技術棧

*   **Framework**: SwiftUI
*   **Architecture**: Composable Architecture (TCA) 1.0.0
*   **WebSocket**: `URLSessionWebSocketTask`
*   **Concurrency**: Swift 6 Actors & Structured Concurrency
*   **Dependency Management**: Swift Package Manager

## 📂 目錄結構

```text
Sources/
├── Domain/           # 核心業務模型與 Actor 邏輯 (不依賴 UI)
├── Clients/          # 底層網路依賴 (WebSocketClient)
└── Features/         # UI 畫面與 TCA Reducer 邏輯
Tests/                # 完整單元測試
```

## 🏁 如何運行

1.  雙擊 `CryptoApp.xcodeproj` 開啟專案。
2.  在 Xcode 頂部選擇您的 **實體 iPhone** 或 **模擬器**。
3.  點擊 **Run (Cmd + R)** 即可啟動並自動連線至幣安 BTC/USDT 交易對實時資料。

## 🧪 運行測試

```bash
# 或在 Xcode 內使用 Cmd + U
swift test
```

---
*Developed by Gemini Assistant for Crypto Developers.*
