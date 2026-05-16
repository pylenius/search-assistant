import SwiftUI

struct ContentView: View {
    /// Navigation stack of slugs. Pushing a slug brings up SearchView.
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            LandingView { slug in
                path.append(slug)
            }
            .navigationDestination(for: String.self) { slug in
                SearchView(slug: slug)
            }
        }
    }
}

#Preview {
    ContentView()
}
