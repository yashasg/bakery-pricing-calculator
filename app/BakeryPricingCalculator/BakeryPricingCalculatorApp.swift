import SwiftUI

@main
struct BakeryPricingCalculatorApp: App {
    var body: some Scene {
        WindowGroup {
            // Satoshi is set as the default font for all views in this window.
            // To override for a specific view, apply .font(...) directly on that view.
            ContentView()
                .font(.satoshiBody)
        }
    }
}
