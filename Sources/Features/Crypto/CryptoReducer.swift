import ComposableArchitecture
import SwiftUI
import Foundation

import ComposableArchitecture
import SwiftUI
import Foundation

public struct CryptoReducer: Reducer, Sendable {
    public struct CoinState: Equatable, Identifiable {
        public let id: String // Symbol
        public var currentPrice: Double?
        public var lastPrice: Double?
        public var status: String = "Waiting..."
        public var priceColor: Color = .primary
        public var lastUpdate: Date = .distantPast
        public var klineHistory: [KlineTick] = [] // Keeps the last X candles
        
        public var symbolDisplayName: String {
            id.replacingOccurrences(of: "usdt", with: "").uppercased()
        }
    }
    
    public struct State: Equatable {
        public var coins: IdentifiedArrayOf<CoinState> = []
        public var connectivityStatus: ConnectivityStatus = .disconnected
        
        public init() {
            let initialSymbols = ["btcusdt", "ethusdt", "solusdt", "bnbusdt", "dogeusdt"]
            self.coins = IdentifiedArrayOf(
                uniqueElements: initialSymbols.map { CoinState(id: $0) }
            )
        }
    }
    
    public enum Action: Equatable {
        case onAppear
        case onDisappear
        case receiveKline(KlineTick)
        case updateStatus(ConnectivityStatus)
    }
    
    public enum ConnectivityStatus: String, Equatable {
        case connecting = "Connecting"
        case connected = "Connected"
        case disconnected = "Disconnected"
    }
    
    @Dependency(\.webSocketClient) var webSocketClient
    @Dependency(\.date) var date
    
    private enum CancelID { case webSocket }
    
    public init() {}
    
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.connectivityStatus = .connecting
            
            let symbols = state.coins.map { $0.id }
            // Subscribe to 1m kline
            let streams = symbols.map { "\($0)@kline_1m" }.joined(separator: "/")
            let url = URL(string: "wss://stream.binance.com:9443/stream?streams=\(streams)")!
            
            let client = webSocketClient
            
            return .run { send in
                await send(.updateStatus(.connected))
                let priceActor = PriceActor()
                let stream = try await client.connect(url)
                
                for try await message in stream {
                    let rawData: Data?
                    switch message {
                    case .string(let text):
                        rawData = text.data(using: .utf8)
                    case .data(let data):
                        rawData = data
                    @unknown default:
                        rawData = nil
                    }
                    
                    guard let data = rawData else { continue }
                    
                    if let envelope = try? JSONDecoder().decode(BinanceKlineEnvelopeDTO.self, from: data) {
                        let klineData = envelope.data
                        let kline = klineData.kline
                        
                        if let open = Double(kline.openPrice),
                           let high = Double(kline.highPrice),
                           let low = Double(kline.lowPrice),
                           let close = Double(kline.closePrice) {
                            
                            let tick = KlineTick(
                                symbol: klineData.symbol.lowercased(),
                                open: open,
                                high: high,
                                low: low,
                                close: close,
                                eventTime: klineData.eventTime,
                                openTime: kline.openTime,
                                isClosed: kline.isClosed
                            )
                            
                            if let validTick = await priceActor.process(next: tick) {
                                await send(.receiveKline(validTick))
                            }
                        }
                    }
                }
            } catch: { error, send in
                await send(.updateStatus(.disconnected))
            }
            .cancellable(id: CancelID.webSocket, cancelInFlight: true)
            
        case .onDisappear:
            state.connectivityStatus = .disconnected
            let client = webSocketClient
            return .run { _ in
                await client.disconnect()
            }
            .cancellable(id: CancelID.webSocket)

        case let .receiveKline(tick):
            guard var coin = state.coins[id: tick.symbol] else { return .none }
            
            coin.lastPrice = coin.currentPrice
            coin.currentPrice = tick.close
            coin.lastUpdate = self.date.now
            
            // Manage kline history
            if let lastKline = coin.klineHistory.last, lastKline.openTime == tick.openTime {
                // In the exact same minute candle, just replace it with the latest data
                coin.klineHistory[coin.klineHistory.count - 1] = tick
            } else {
                // A new minute has started, append the new candle
                coin.klineHistory.append(tick)
                // Limit the number of candles displayed to fit the UI smoothly (e.g., last 20 mins)
                if coin.klineHistory.count > 20 {
                    coin.klineHistory.removeFirst()
                }
            }
            
            // Color is based on the candle's open and close
            coin.priceColor = tick.close >= tick.open ? .green : .red
            
            state.coins[id: tick.symbol] = coin
            return .none
            
        case let .updateStatus(status):
            state.connectivityStatus = status
            return .none
        }
    }
}

// MARK: - DTOs

private struct BinanceKlineEnvelopeDTO: Decodable {
    let stream: String
    let data: BinanceKlineDataDTO
}

private struct BinanceKlineDataDTO: Decodable {
    let eventTime: Int64
    let symbol: String
    let kline: BinanceKlineTickDTO
    
    enum CodingKeys: String, CodingKey {
        case eventTime = "E"
        case symbol = "s"
        case kline = "k"
    }
}

private struct BinanceKlineTickDTO: Decodable {
    let openTime: Int64
    let openPrice: String
    let highPrice: String
    let lowPrice: String
    let closePrice: String
    let isClosed: Bool
    
    enum CodingKeys: String, CodingKey {
        case openTime = "t"
        case openPrice = "o"
        case highPrice = "h"
        case lowPrice = "l"
        case closePrice = "c"
        case isClosed = "x"
    }
}
