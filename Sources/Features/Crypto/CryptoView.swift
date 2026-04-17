import SwiftUI
import ComposableArchitecture
import Charts

public struct CryptoView: View {
    let store: StoreOf<CryptoReducer>
    
    // 監聽 App 的前景/背景狀態
    @Environment(\.scenePhase) private var scenePhase
    
    public init(store: StoreOf<CryptoReducer>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            NavigationStack {
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
                                    NavigationLink(value: coin.id) {
                                        CoinCardView(coin: coin)
                                    }
                                    .buttonStyle(.plain)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 30)
                        }
                    }
                }
                .navigationDestination(for: String.self) { coinId in
                    WithViewStore(self.store, observe: { $0.coins[id: coinId] }) { coinViewStore in
                        if let coin = coinViewStore.state {
                            CoinDetailView(coin: coin)
                        } else {
                            Text("Coin not found").foregroundColor(.white)
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { viewStore.send(.onAppear) }
            .onDisappear { viewStore.send(.onDisappear) }
            // 監聽前景/背景切換，確保 WebSocket 連線不中斷
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .active:
                    // 回到前台：若狀態為 disconnected，重新啟動連線
                    if viewStore.connectivityStatus == .disconnected {
                        viewStore.send(.onAppear)
                    }
                case .background:
                    // 進入背景：主動斷開連線，避免 iOS 在背景強制終止造成狀態不一致
                    viewStore.send(.onDisappear)
                default:
                    break
                }
            }
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
                
                // Sparkline Chart for list view
                RealtimeSparkline(history: coin.sparklineBuffer, color: coin.priceColor)
                    .frame(width: 100, height: 35)
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

// MARK: - Coin Detail View (Navigation Push)

private struct CoinDetailView: View {
    let coin: CryptoReducer.CoinState
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header Status
                    HStack {
                        SymbolIcon(symbol: coin.id)
                            .scaleEffect(1.5)
                            .padding(.trailing, 10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(coin.symbolDisplayName)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(coin.id.uppercased())
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Current Price
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAST PRICE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        
                        HStack {
                            Text(String(format: "$%.2f", coin.currentPrice ?? 0))
                                .font(.system(size: 50, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: coin.priceColor.opacity(isPulsing ? 1.0 : 0.0), radius: 15)
                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: coin.currentPrice)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // OHLC Stats of Current Candle
                    if let currentCandle = coin.klineHistory.last {
                        HStack {
                            StatBox(title: "OPEN", value: currentCandle.open)
                            StatBox(title: "HIGH", value: currentCandle.high)
                            StatBox(title: "LOW", value: currentCandle.low)
                            StatBox(title: "CLOSE", value: currentCandle.close)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Professional Trend Line
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1H PRICE TREND")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 24)
                        
                        RealtimeSparkline(history: coin.sparklineBuffer, color: coin.priceColor)
                            .frame(height: 250)
                            .padding()
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .navigationTitle(coin.symbolDisplayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: coin.currentPrice) { _ in
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
}

private struct StatBox: View {
    let title: String
    let value: Double
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
            Text(String(format: "%.2f", value))
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Restore RealtimeSparkline
private struct RealtimeSparkline: View {
    let history: [Double]
    let color: Color
    
    @State private var wavePhase: Double = 0
    
    private var priceRange: (min: Double, max: Double) {
        let min = history.min() ?? 0
        let max = history.max() ?? 0
        if min == max { return (min: min * 0.9999, max: max * 1.0001) }
        let delta = max - min
        return (min: min - (delta * 0.05), max: max + (delta * 0.05))
    }
    
    private var chartData: [(index: Int, price: Double)] {
        if history.isEmpty { return [] }
        if history.count == 1 {
            return [(index: 0, price: history[0]), (index: 1, price: history[0])]
        }
        return history.enumerated().map { (index: $0.offset, price: $0.element) }
    }
    
    var body: some View {
        if history.isEmpty {
            // Skeleton Loader: Animated Sine Wave
            Chart {
                ForEach(0..<40, id: \.self) { index in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Price", sin(Double(index) * 0.3 + wavePhase))
                    )
                    .foregroundStyle(Color.white.opacity(0.1))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    
                    AreaMark(
                        x: .value("Index", index),
                        yStart: .value("Min", -1.5),
                        yEnd: .value("Price", sin(Double(index) * 0.3 + wavePhase))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.05), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: -1.5...1.5)
            .chartXScale(domain: 0...39)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    wavePhase -= .pi * 2
                }
            }
        } else {
            Chart {
                ForEach(chartData, id: \.index) { item in
                    LineMark(
                        x: .value("Index", item.index),
                        y: .value("Price", item.price)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    AreaMark(
                        x: .value("Index", item.index),
                        yStart: .value("Min", priceRange.min),
                        yEnd: .value("Price", item.price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.5), color.opacity(0.0)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: priceRange.min...priceRange.max)
            .chartXScale(domain: 0...39) // Fixed domain to create left-to-right growth effect
            .animation(.easeInOut(duration: 0.1), value: history.last ?? 0)
        }
    }
}
