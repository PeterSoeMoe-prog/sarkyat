import SwiftUI

struct CollapsibleSearchBox: View {
    @Binding var searchText: String
    @State private var expanded = false
    @FocusState private var isFocused: Bool
    @AppStorage("sessionPaused") private var sessionPaused: Bool = false

    // Google-style pill search bar
    var body: some View {
        HStack(spacing: 0) {
            if expanded {
                HStack(spacing: 0) {
                    TextField("Search Thai or Burmese...", text: $searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .padding(.vertical, 8)
                        .focused($isFocused)
                        .onAppear { DispatchQueue.main.async { isFocused = true } }
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                            
                                .foregroundColor(.gray)
                        }
                    }
                    Button(action: {
                        withAnimation { expanded = false }
                        isFocused = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // Collapsed pill only magnifying glass
                Button(action: {
                    withAnimation { expanded = true }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 19.5))  // Approximately 30% larger than default
                        .foregroundColor(.accentColor)
                }
            }
            // Test buttons OUTSIDE capsule when collapsed
            if !expanded {
                ForEach(1...5, id: \.self) { i in
                    if i == 1 {
                        Button("10X ▶") {
                            NotificationCenter.default.post(name: .play10X, object: nil)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        
                        
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                    } else if i == 2 {
                        Button("10X ↻") {
                            NotificationCenter.default.post(name: .playRecent10, object: nil)
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        
                        
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                    } else if i == 3 {
                        Button(action: {
                            sessionPaused = false
                            NotificationCenter.default.post(name: .nextVocabulary, object: nil)
                        }) {
                            Image(systemName: "play")
                                .imageScale(.large)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        
                        
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                    } else if i == 4 {
                        // Home button
                        Button(action: {
                            NotificationCenter.default.post(name: .homeAction, object: nil)
                        }) {
                            Image(systemName: "house")
                                .imageScale(.large)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                        
                        // Plus button (add word) – placed right after Home
                        Button(action: {
                            NotificationCenter.default.post(name: .addWord, object: nil)
                        }) {
                            Image(systemName: "plus")
                                .imageScale(.large)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                        
                        // Settings button (gear)
                        Button(action: {
                            NotificationCenter.default.post(name: Notification.Name("showSettings"), object: nil)
                        }) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                    } else if i == 5 {
   
                        
                        
                    } else {
                        Button(action: {
                            NotificationCenter.default.post(name: .addWord, object: nil)
                        }) {
                            
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        
                        
                        .clipShape(Capsule())
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .onTapGesture {
            if !expanded {
                withAnimation(.spring()) { expanded = true }
            }
        }
        .onChange(of: expanded) { _, newValue in
            if newValue {
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .animation(.easeInOut, value: expanded)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
