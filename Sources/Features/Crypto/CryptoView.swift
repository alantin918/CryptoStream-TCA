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
                                    // 不加 transition，避免每次資料更新時觸發從下往上的滑入動畫
                                }
                            }
                            .animation(nil, value: viewStore.coins) // 資料更新時不做列表動畫
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 30)
                        }
                    }
                }
                .navigationDestination(for: String.self) { coinId in
                    WithViewStore(self.store, observe: { $0.coins[id: coinId] }) { coinViewStore in
                        if let coin = coinViewStore.state {
                            CoinDetailView(coin: coin, send: { coinViewStore.send($0) })
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
                CapsuleIndicator(color: coin.currentPrice != nil ? coin.priceColor : .gray)
            }
            
            HStack(alignment: .bottom) {
                // Price Display
                VStack(alignment: .leading, spacing: 4) {
                    if let price = coin.currentPrice {
                        Text(price, format: .currency(code: "USD").presentation(.narrow))
                            .font(.system(size: 28, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            // 只用 shadow 做視覺提示，不影響佈局
                            .shadow(color: coin.priceColor.opacity(0.6), radius: 8)
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
    let send: (CryptoReducer.Action) -> Void
    
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
                                .font(.system(size: 44, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .shadow(color: coin.priceColor.opacity(0.6), radius: 12)
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
                    
                    // Professional Trend Line & Timeframe Selection
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("MARKET TREND")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Spacer()
                            
                            // Timeframe Picker
                            HStack(spacing: 8) {
                                ForEach(CryptoReducer.Timeframe.allCases, id: \.self) { tf in
                                    Button(action: {
                                        send(.selectTimeframe(coinId: coin.id, timeframe: tf))
                                    }) {
                                        Text(tf.displayName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(coin.selectedTimeframe == tf ? .white : .white.opacity(0.4))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(coin.selectedTimeframe == tf ? Color.white.opacity(0.2) : Color.clear)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Main MA Chart
                        HistoricalMAChart(
                            prices: coin.historicalPrices,
                            isFetching: coin.isFetchingHistory,
                            priceColor: coin.priceColor
                        )
                        .frame(height: 280)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .navigationTitle(coin.symbolDisplayName)
        .onAppear {
            if coin.historicalPrices.isEmpty {
                send(.selectTimeframe(coinId: coin.id, timeframe: coin.selectedTimeframe))
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

// MARK: - RealtimeSparkline (Canvas-based, zero animation)
private struct RealtimeSparkline: View {
    let history: [Double]
    let color: Color

    var body: some View {
        if history.isEmpty {
            // 靜態虛線佔位符，完全無動畫，不影響佈局
            Canvas { context, size in
                var dashPath = Path()
                let y = size.height / 2
                dashPath.move(to: CGPoint(x: 0, y: y))
                dashPath.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    dashPath,
                    with: .color(Color.white.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        } else {
            // Canvas-based drawing: no SwiftUI Charts, no implicit transitions, no floating
            Canvas { context, size in
                guard history.count >= 1 else { return }

                let minVal = history.min() ?? 0
                let maxVal = history.max() ?? 1
                let delta = maxVal - minVal
                // 最小縮放 0.2%，防止平盤時 Y 軸過度放大
                let minDelta = max(delta, (maxVal + minVal) / 2 * 0.002)
                let padding = minDelta * 0.1
                let low  = ((maxVal + minVal) / 2) - (minDelta / 2) - padding
                let high = ((maxVal + minVal) / 2) + (minDelta / 2) + padding
                let range = high - low

                let totalSlots: CGFloat = 40
                let xStep = size.width / totalSlots

                func xPos(_ i: Int) -> CGFloat { CGFloat(i) * xStep }
                func yPos(_ v: Double) -> CGFloat {
                    size.height - CGFloat((v - low) / range) * size.height
                }

                // --- Gradient area fill ---
                var areaPath = Path()
                areaPath.move(to: CGPoint(x: xPos(0), y: size.height))
                for (i, price) in history.enumerated() {
                    areaPath.addLine(to: CGPoint(x: xPos(i), y: yPos(price)))
                }
                areaPath.addLine(to: CGPoint(x: xPos(history.count - 1), y: size.height))
                areaPath.closeSubpath()

                context.fill(
                    areaPath,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.4), color.opacity(0.0)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // --- Line ---
                var linePath = Path()
                for (i, price) in history.enumerated() {
                    let pt = CGPoint(x: xPos(i), y: yPos(price))
                    if i == 0 { linePath.move(to: pt) }
                    else { linePath.addLine(to: pt) }
                }
                context.stroke(
                    linePath,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - Historical MA Chart

private struct HistoricalMAChart: View {
    let prices: [Double]
    let isFetching: Bool
    let priceColor: Color
    
    let ma7Color = Color(red: 0.95, green: 0.73, blue: 0.18) // Binance Yellow
    let ma25Color = Color(red: 0.88, green: 0.35, blue: 0.97) // Pink/Purple
    let ma99Color = Color(red: 0.31, green: 0.78, blue: 0.47) // Teal
    
    // Simple Moving Average
    private func calculateMA(period: Int, data: [Double]) -> [Double?] {
        guard period > 0, data.count > 0 else { return [] }
        var result: [Double?] = []
        for i in 0..<data.count {
            if i < period - 1 {
                result.append(nil)
            } else {
                let sum = data[(i - period + 1)...i].reduce(0, +)
                result.append(sum / Double(period))
            }
        }
        return result
    }
    
    private func legendItem(title: String, value: Double?, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
            if let val = value {
                Text(String(format: "%.2f", val))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
    }

    var body: some View {
        let ma7 = calculateMA(period: 7, data: prices)
        let ma25 = calculateMA(period: 25, data: prices)
        let ma99 = calculateMA(period: 99, data: prices)
        
        let currMA7 = ma7.last ?? nil
        let currMA25 = ma25.last ?? nil
        let currMA99 = ma99.last ?? nil

        VStack(spacing: 8) {
            // Legend
            HStack(spacing: 12) {
                legendItem(title: "MA(7)", value: currMA7, color: ma7Color)
                legendItem(title: "MA(25)", value: currMA25, color: ma25Color)
                legendItem(title: "MA(99)", value: currMA99, color: ma99Color)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 20)

            // Chart
            ZStack {
                Color.white.opacity(0.02)
                    .cornerRadius(16)
                
                if isFetching && prices.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else if prices.isEmpty {
                    Text("No Data")
                        .foregroundColor(.white.opacity(0.4))
                } else {
                    Canvas { context, size in
                        let allPoints = prices + ma7.compactMap{$0} + ma25.compactMap{$0} + ma99.compactMap{$0}
                        guard let minVal = allPoints.min(), let maxVal = allPoints.max() else { return }
                        
                        let delta = maxVal - minVal
                        let minDelta = max(delta, (maxVal + minVal) / 2 * 0.002)
                        let padding = minDelta * 0.1
                        let low  = ((maxVal + minVal) / 2) - (minDelta / 2) - padding
                        let high = ((maxVal + minVal) / 2) + (minDelta / 2) + padding
                        let range = high - low
                        
                        let xStep = size.width / CGFloat(max(1, prices.count - 1))
                        
                        func xPos(_ i: Int) -> CGFloat { CGFloat(i) * xStep }
                        func yPos(_ v: Double) -> CGFloat {
                            size.height - CGFloat((v - low) / range) * size.height
                        }
                        
                        func drawPath(data: [Double?], color: Color, lineWidth: CGFloat = 1.0) {
                            var path = Path()
                            var isFirst = true
                            for (i, val) in data.enumerated() {
                                if let v = val {
                                    let pt = CGPoint(x: xPos(i), y: yPos(v))
                                    if isFirst {
                                        path.move(to: pt)
                                        isFirst = false
                                    } else {
                                        path.addLine(to: pt)
                                    }
                                }
                            }
                            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        }
                        
                        // Fill Area for Price
                        var areaPath = Path()
                        areaPath.move(to: CGPoint(x: xPos(0), y: size.height))
                        for (i, p) in prices.enumerated() {
                            areaPath.addLine(to: CGPoint(x: xPos(i), y: yPos(p)))
                        }
                        areaPath.addLine(to: CGPoint(x: xPos(prices.count - 1), y: size.height))
                        areaPath.closeSubpath()
                        context.fill(
                            areaPath,
                            with: .linearGradient(
                                Gradient(colors: [priceColor.opacity(0.3), priceColor.opacity(0.0)]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: size.height)
                            )
                        )
                        
                        // Draw lines
                        drawPath(data: prices.map { $0 }, color: priceColor, lineWidth: 2)
                        drawPath(data: ma99, color: ma99Color)
                        drawPath(data: ma25, color: ma25Color)
                        drawPath(data: ma7, color: ma7Color)
                        
                    }
                    .padding()
                }
            }
        }
    }
}

