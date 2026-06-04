import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "app.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .accessibilityHidden(true) // decorative placeholder — replace with a labelled asset
            Text("Hello, BakeryPricingCalculator")
                .font(.satoshiTitle)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
