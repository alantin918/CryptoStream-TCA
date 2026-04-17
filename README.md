# CryptoStream-TCA

> A production-quality iOS cryptocurrency dashboard built with **The Composable Architecture (TCA)**, featuring real-time Binance WebSocket streaming, Swift 6 strict concurrency, and a premium Glassmorphism UI.

[![CI](https://github.com/alantin918/CryptoStream-TCA/actions/workflows/ci.yml/badge.svg)](https://github.com/alantin918/CryptoStream-TCA/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue?logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-TCA-purple)

---

## ✨ Features

| Feature | Description |
|---|---|
| 📉 **Historical MA Charts** | Professional details view with 1H/1D/1W/1M timeframe selection and MA(7, 25, 99) overlays |
| 📊 **Zero-Jitter Canvas UI** | Custom `Canvas`-based sparklines and historical charts that eliminate SwiftUI implicit animation lag and layout shifts |
| ⚡ **WebSocket Streaming** | Connects to Binance public WebSocket API for BTC, ETH, SOL, BNB & DOGE |
| 🧵 **Swift 6 Concurrency** | `PriceActor` enforces thread-safe state with timestamp-based out-of-order rejection |
| 🎚️ **10Hz Throttling** | Per-symbol throttle gate prevents UI overload without dropping data integrity |
| 🔄 **Auto-Reconnect** | Detects foreground/background transitions via `scenePhase` and reconnects automatically |
| 💎 **Glassmorphism UI** | Dark mode, `.ultraThinMaterial` cards, monospaced digits, and ambient light blobs |
| 🧪 **13 Test Cases** | Unit, integration, and concurrency stress tests covering the full data pipeline and chart state transitions |

---

## 🏗️ Architecture

This project follows **Clean Architecture** principles layered on top of TCA's unidirectional data flow:

```
CryptoStream-TCA/
├── Sources/
│   ├── Clients/
│   │   └── WebSocketClient/     # Network abstraction (dependency-injected)
│   ├── Domain/
│   │   ├── Actors/
│   │   │   └── PriceActor       # Swift Actor: throttling + out-of-order filtering
│   │   └── Models/
│   │       └── PriceTick        # Core domain model
│   └── Features/
│       └── Crypto/
│           ├── CryptoReducer    # TCA Reducer: state machine + side effects
│           └── CryptoView       # SwiftUI View + real-time sparkline charts
└── Tests/
    └── CryptoStream-TCATests/
        ├── CryptoStream_TCATests    # Reducer & Actor unit tests
        └── CryptoAdvancedTests      # Concurrency stress & integration tests
```

### Data Flow

```
Binance WSS → WebSocketClient → CryptoReducer → PriceActor (10Hz gate) → State → SwiftUI
```

---

## 🧪 Test Coverage

| Test Suite | Cases | Description |
|---|---|---|
| `CryptoReducerTests` | 4 | Price coloring, lifecycle, error recovery, symbol filter |
| `PriceActorTests` | 2 | 10Hz throttle validation, multi-symbol independence |
| `PriceActorConcurrencyTests` | 4 | Burst (100 concurrent tasks), sequential stress, cross-symbol isolation, out-of-order rejection |
| `CryptoIntegrationTests` | 2 | End-to-end WebSocket → Actor → State pipeline, malformed JSON resilience |

---

## 🚀 Getting Started

### Requirements

- Xcode 16.2+
- iOS 16+ Simulator or Device
- macOS 13+ (for running unit tests)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/alantin918/CryptoStream-TCA.git
cd CryptoStream-TCA
```

2. Setup Apple Development Team ID (prevents re-selection on every git pull):
```bash
echo "YOUR_TEAM_ID" > .teamid
```

3. Generate the Xcode project:
```bash
ruby generate.rb
```

4. Open the generated `CryptoApp.xcodeproj`
> Xcode will automatically resolve the Swift Package dependencies on first open.

### Running the App

1. Open `CryptoApp.xcodeproj`
2. Select an iOS 16+ Simulator
3. Press `Cmd + R` — the app will connect to Binance and start streaming live prices immediately

### Running Tests

```bash
# In Xcode
Cmd + U

# Or via command line
xcodebuild test \
  -workspace . \
  -scheme CryptoStream-TCA \
  -destination "platform=macOS" \
  -skipMacroValidation
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| Architecture | The Composable Architecture (TCA 1.17+) |
| UI | SwiftUI + custom `Canvas` drawing |
| Concurrency | Swift Actor, AsyncThrowingStream |
| Networking | URLSessionWebSocketTask |
| Testing | XCTest, TCA TestStore |
| CI | GitHub Actions on macOS 15 + Xcode 16.2 |

---

## 📄 License

This project is available under the MIT License.
