import SwiftUI
import ComposableArchitecture
import Charts

public struct CryptoView: View {
    let store: StoreOf<CryptoReducer>
    
    public init(store: StoreOf<CryptoReducer>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            ZStack {
                // 1. Sleek Dark Gradient Background
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Animated ambient light blobs for "Premium" look
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 100)
                        .offset(x: -150, y: -200)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 100)
                        .offset(x: 150, y: 200)
                }
                
                VStack(spacing: 0) {
                    // Header Area
                    HeaderView(status: viewStore.connectivityStatus)
                    
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 20) {
                            ForEach(viewStore.coins) { coin in
                                CoinCardView(coin: coin)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { viewStore.send(.onAppear) }
            .onDisappear { viewStore.send(.onDisappear) }
        }
    }
}

// MARK: - Header Component

private struct HeaderView: View {
    let status: CryptoReducer.ConnectivityStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Crypto Dashboard")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Real-time Binance Feed")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(1)
            }
            
            Spacer()
            
            HeaderStatusIndicator(status: status)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Individual Coin Card

private struct CoinCardView: View {
    let coin: CryptoReducer.CoinState
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Symbol Info
                HStack(spacing: 12) {
                    SymbolIcon(symbol: coin.id)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coin.symbolDisplayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Binance")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Indicators
                if coin.currentPrice != nil {
                    CapsuleIndicator(color: coin.priceColor)
                }
            }
            
            HStack(alignment: .bottom) {
                // Price Display
                VStack(alignment: .leading, spacing: 4) {
                    if let price = coin.currentPrice {
                        Text(price, format: .currency(code: "USD").presentation(.narrow))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: coin.priceColor.opacity(isPulsing ? 1.0 : 0), radius: 10)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: price)
                    } else {
                        Text("---.---")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                
                Spacer()
                
                // Real-time Sparkline (using SwiftUI Charts)
                RealtimeSparkline(history: coin.priceHistory, color: coin.priceColor)
                    .frame(width: 80, height: 35)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.2), .white.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .scaleEffect(isPulsing ? 1.02 : 1.0)
        .onChange(of: coin.currentPrice) { _ in
            triggerPulse()
        }
    }
    
    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.1)) {
            isPulsing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.3)) {
                isPulsing = false
            }
        }
    }
}

// MARK: - Subcomponents

private struct SymbolIcon: View {
    let symbol: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(themeColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(themeColor)
                .shadow(color: themeColor.opacity(0.5), radius: 5)
        }
    }
    
    private var iconName: String {
        switch symbol {
        case "btcusdt": return "bitcoinsign.circle.fill"
        case "ethusdt": return "diamond.fill"
        case "solusdt": return "s.circle.fill"
        case "bnbusdt": return "b.circle.fill"
        default: return "chart.bar.fill"
        }
    }
    
    private var themeColor: Color {
        switch symbol {
        case "btcusdt": return .orange
        case "ethusdt": return .blue
        case "solusdt": return .purple
        case "bnbusdt": return .yellow
        default: return .gray
        }
    }
}

private struct RealtimeSparkline: View {
    let history: [Double]
    let color: Color
    
    var body: some View {
        // Only show chart if we have at least 2 points
        if history.count < 2 {
            // Placeholder while gathering initial data
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .overlay(Text("LOADING").font(.system(size: 8, weight: .black)).foregroundColor(.white.opacity(0.2)))
        } else {
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, price in
                    // The glowing line
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Price", price)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    // The soft gradient area fill
                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Price", price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.2), color.opacity(0.0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            // Critical for "Sparkline" effect: don't start at zero, focus on the price delta
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXScale(domain: .automatic(includesZero: false))
        }
    }
}

private struct CapsuleIndicator: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color, radius: 4)
    }
}

private struct HeaderStatusIndicator: View {
    let status: CryptoReducer.ConnectivityStatus
    @State private var isBlinking = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isBlinking ? 1.2 : 0.8)
                .animation(status == .connected ? .easeInOut(duration: 1.0).repeatForever() : .default, value: isBlinking)
            
            Text(status.rawValue.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.05)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .onAppear { if status == .connected { isBlinking = true } }
        .onChange(of: status) { isBlinking = ($0 == .connected) }
    }
    
    private var statusColor: Color {
        switch status {
        case .connecting: return .yellow
        case .connected: return .green
        case .disconnected: return .red
        }
    }
}

