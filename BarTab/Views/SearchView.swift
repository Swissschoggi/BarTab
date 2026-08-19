import SwiftUI

struct SearchView: View {

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.barTabPrimary)

                Text("Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.barTabText)

                Text("Search for bars coming soon.")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Search")
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
