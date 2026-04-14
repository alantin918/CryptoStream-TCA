import SwiftUI
import ComposableArchitecture

@main
struct CryptoApp: App {
    var body: some Scene {
        WindowGroup {
            CryptoView(
                store: Store(initialState: CryptoReducer.State()) {
                    CryptoReducer()
                }
            )
        }
    }
}
