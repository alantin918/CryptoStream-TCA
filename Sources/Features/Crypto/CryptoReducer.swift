import ComposableArchitecture
import SwiftUI
import Foundation

public typealias CryptoPrice = PriceTick

public struct CryptoReducer: Reducer {
    public struct State: Equatable {
        public var currentPrice: CryptoPrice?
        public var priceColor: Color = .primary
        public var connectivityStatus: ConnectivityStatus = .disconnected
        
        public init() {}
    }
    
    public enum Action: Equatable {
        case onAppear
        case onDisappear
        case receivePrice(CryptoPrice)
        case updateStatus(ConnectivityStatus)
    }
    
    public enum ConnectivityStatus: String, Equatable {
        case connecting = "Connecting"
        case connected = "Connected"
        case disconnected = "Disconnected"
    }
    
    @Dependency(\.webSocketClient) var webSocketClient
    
    private enum CancelID { case webSocket }
    
    public init() {}
    
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            state.connectivityStatus = .connecting
            let url = URL(string: "wss://stream.binance.com:9443/ws/btcusdt@trade")!
            
            return .run { send in
                defer {
                    print("CryptoReducer Lifecycle: .run effect terminated.")
                }
                
                await send(.updateStatus(.connected))
                let priceActor = PriceActor()
                let stream = try await webSocketClient.connect(url)
                
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
                    
                    if let trade = try? JSONDecoder().decode(BinanceTradeDTO.self, from: data),
                       let priceDouble = Double(trade.price) {
                        
                        let tick = CryptoPrice(
                            symbol: trade.symbol,
                            price: priceDouble,
                            timestamp: trade.eventTime
                        )
                        
                        if let validTick = await priceActor.process(next: tick) {
                            await send(.receivePrice(validTick))
                        }
                    }
                }
            } catch: { error, send in
                await send(.updateStatus(.disconnected))
            }
            .cancellable(id: CancelID.webSocket, cancelInFlight: true)
            
        case .onDisappear:
            state.connectivityStatus = .disconnected
            return .run { _ in
                await webSocketClient.disconnect()
            }
            .cancellable(id: CancelID.webSocket)
            
        case let .receivePrice(newPrice):
            if let oldPrice = state.currentPrice {
                if newPrice.price > oldPrice.price {
                    state.priceColor = .green
                } else if newPrice.price < oldPrice.price {
                    state.priceColor = .red
                }
            }
            state.currentPrice = newPrice
            return .none
            
        case let .updateStatus(status):
            state.connectivityStatus = status
            return .none
        }
    }
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
