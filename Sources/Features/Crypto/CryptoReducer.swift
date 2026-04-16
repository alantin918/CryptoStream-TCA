import ComposableArchitecture
import SwiftUI
import Foundation

public typealias CryptoPrice = PriceTick

public struct CryptoReducer: Reducer, Sendable {
    public struct CoinState: Equatable, Identifiable {
        public let id: String // Symbol
        public var currentPrice: Double?
        public var lastPrice: Double?
        public var status: String = "Waiting..."
        public var priceColor: Color = .primary
        public var lastUpdate: Date = .distantPast
        public var priceHistory: [Double] = []
        
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
        case receivePrice(PriceTick)
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
            let streams = symbols.map { "\($0)@trade" }.joined(separator: "/")
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
                    
                    if let envelope = try? JSONDecoder().decode(BinanceEnvelopeDTO.self, from: data) {
                        let trade = envelope.data
                        if let priceDouble = Double(trade.price) {
                            let tick = PriceTick(
                                symbol: trade.symbol.lowercased(),
                                price: priceDouble,
                                timestamp: trade.eventTime
                            )
                            
                            if let validTick = await priceActor.process(next: tick) {
                                await send(.receivePrice(validTick))
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

        case let .receivePrice(tick):
            guard var coin = state.coins[id: tick.symbol] else { return .none }
            
            coin.lastPrice = coin.currentPrice
            coin.currentPrice = tick.price
            coin.lastUpdate = self.date.now
            
            // Update history (last 100 points for ~10 seconds of history at 10Hz)
            coin.priceHistory.append(tick.price)
            if coin.priceHistory.count > 100 {
                coin.priceHistory.removeFirst()
            }
            
            if let last = coin.lastPrice {
                if tick.price > last {
                    coin.priceColor = .green
                } else if tick.price < last {
                    coin.priceColor = .red
                }
            }
            
            state.coins[id: tick.symbol] = coin
            return .none
            
        case let .updateStatus(status):
            state.connectivityStatus = status
            return .none
        }
    }
}

// MARK: - DTOs

private struct BinanceEnvelopeDTO: Decodable {
    let stream: String
    let data: BinanceTradeDTO
}

private struct BinanceTradeDTO: Decodable {
    let symbol: String
    let price: String
    let eventTime: Int64
    
    enum CodingKeys: String, CodingKey {
        case symbol = "s"
        case price = "p"
        case eventTime = "E"
    }
}
