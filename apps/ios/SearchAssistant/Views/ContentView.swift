import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Search Assistant")
                .font(.largeTitle.weight(.semibold))
            Text("Native iOS scaffold — build steps come next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
