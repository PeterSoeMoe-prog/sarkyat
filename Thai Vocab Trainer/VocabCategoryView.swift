import SwiftUI

/// Temporary placeholder for the main category grid. Replace once the new design is ready.
struct VocabCategoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.grid.2x2")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            Text("Vocabulary Categories")
                .font(.title)
                .fontWeight(.semibold)
            Text("This screen will be rebuilt soon.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Categories")
    }
}

#Preview {
    VocabCategoryView()
}
