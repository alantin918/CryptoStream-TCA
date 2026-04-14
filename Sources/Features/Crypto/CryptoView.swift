import SwiftUI
import ComposableArchitecture

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
                    gradient: Gradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar (Status Indicator)
                    HStack {
                        Spacer()
                        HeaderStatusIndicator(status: viewStore.connectivityStatus)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    if let price = viewStore.currentPrice {
                        // Main Price Card
                        PriceCardView(
                            price: price,
                            color: viewStore.priceColor
                        )
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        // Loading State Screen
                        VStack(spacing: 24) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("CONNECTING TO BINANCE...")
                                .font(.caption)
                                .fontWeight(.bold)
                                .kerning(2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    Spacer() // Slightly visually lifts the main content
                }
            }
            .preferredColorScheme(.dark)
            // Bind Lifecycle -> Reducer Actions
            .onAppear { viewStore.send(.onAppear) }
            .onDisappear { viewStore.send(.onDisappear) }
        }
    }
}

// MARK: - Glassmorphism UI Card

private struct PriceCardView: View {
    let price: CryptoPrice
    let color: Color
    
    // State for local micro-animations
    @State private var isPulsing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            
            // Header: Symbol & Animated Status Dot
            HStack {
                Image(systemName: "bitcoinsign.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.orange)
                    .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 0)
                
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("BTC")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    
                    Text("/USDT")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Color trend indicator shadow dot
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .shadow(color: color.opacity(0.8), radius: isPulsing ? 12 : 2)
            }
            
            // Body: Animated Price Data
            VStack(alignment: .leading, spacing: 8) {
                Text(price.price, format: .currency(code: "USD").presentation(.narrow))
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    // The pulse shadow flashes intensely upon data update
                    .shadow(color: color.opacity(isPulsing ? 0.6 : 0), radius: isPulsing ? 16 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: price.price)
                
                Text("Last updated: \(timestampString(from: price.timestamp))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                // Ambient dynamic shadow projecting downward
                .shadow(color: color.opacity(0.15), radius: 30, x: 0, y: 15)
        )
        // Premium outline stroke effect for glass edges
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(LinearGradient(
                    gradient: Gradient(colors: [.white.opacity(0.3), .white.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        // Whenever the price changes, trigger our rapid micro-animation sequence
        .onChange(of: price.price) { _ in
            triggerPulse()
        }
    }
    
    private func triggerPulse() {
        withAnimation(.easeOut(duration: 0.1)) {
            isPulsing = true
        }
        // Swiftly decay the flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.4)) {
                isPulsing = false
            }
        }
    }
    
    private func timestampString(from epochMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epochMs) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SS"
        return formatter.string(from: date)
    }
}

// MARK: - Premium Status Pill Indicator

private struct HeaderStatusIndicator: View {
    let status: CryptoReducer.ConnectivityStatus
    
    @State private var isBlinking = false
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.8), radius: isBlinking ? 8 : 0)
                // Infinity breathing scale & glow animation for connected state
                .scaleEffect(isBlinking ? 1.2 : 0.8)
                .animation(status == .connected ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: isBlinking)
            
            Text(status.rawValue.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .animation(.none, value: status) // Prevent slide transitions on text
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(.ultraThinMaterial))
        // Glass capsule stroke
        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
        .onChange(of: status) { newStatus in
            if newStatus == .connected {
                isBlinking = true
            } else {
                isBlinking = false
            }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connecting: return .yellow
        case .connected: return .green
        case .disconnected: return .red
        }
    }
}
