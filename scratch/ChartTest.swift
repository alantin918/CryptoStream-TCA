import SwiftUI
import Charts

struct ChartTestView: View {
    @State var history: [Double] = [65000.0, 65000.1, 65000.05, 65000.15, 65000.1]
    
    var body: some View {
        VStack {
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, price in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("Price", price)
                    )
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 100)
            .padding()
            .background(Color.gray.opacity(0.1))
            
            Button("Add Jitter") {
                let last = history.last ?? 65000.0
                history.append(last + Double.random(in: -0.05...0.05))
                if history.count > 20 { history.removeFirst() }
            }
        }
    }
}
