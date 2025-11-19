import SwiftUI

/// Grid-style view for displaying vocabulary categories.
/// Currently uses placeholder cells; hook up with real category data later.
struct VocabCategoryView: View {

    @StateObject private var viewModel = CategoryViewModel()
    @State private var tappedCategory: String? = nil
    @State private var sortOption: SortOption = .name
    @State private var filterOption: FilterOption = .all
    @State private var searchText: String = ""
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case progress = "Progress"
        case completion = "Status"
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case incomplete = "Incomplete"
    }

    // Neon gradient palette
    private let gradientPairs: [[Color]] = [
        [.pink, .purple],
        [.cyan, .blue],
        [.orange, .red],
        [.green, .mint],
        [.yellow, .orange],
        [.teal, .indigo]
    ]

    // 2 columns, square cells
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // Filtered and sorted stats
    private var filteredAndSortedStats: [CategoryViewModel.Stat] {
        var stats = viewModel.stats
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .completed:
            stats = stats.filter { $0.percent == 100 }
        case .incomplete:
            stats = stats.filter { $0.percent < 100 }
        }
        
        // Apply sort
        switch sortOption {
        case .name:
            stats.sort { $0.name < $1.name }
        case .progress:
            stats.sort { $0.percent > $1.percent }
        case .completion:
            stats.sort { ($0.percent == 100 ? 0 : 1) < ($1.percent == 100 ? 0 : 1) }
        }
        
        // Apply search filter
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            stats = stats.filter { $0.name.lowercased().contains(q) }
        }
        
        return stats
    }

    var body: some View {
        ScrollView {
            // Stats Summary Header
            VStack(spacing: 12) {
                let completedCount = viewModel.stats.filter { $0.percent == 100 }.count
                let totalCategories = viewModel.stats.count
                let overallProgress = totalCategories > 0 ? (completedCount * 100) / totalCategories : 0
                
                HStack(spacing: 0) {
                    // Completed categories
                    VStack(spacing: 6) {
                        Text("\(completedCount)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Completed")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Total categories
                    VStack(spacing: 6) {
                        Text("\(totalCategories)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Total")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Overall progress
                    VStack(spacing: 6) {
                        Text("\(overallProgress)%")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Progress")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            
            // Sort, Filter, and Search Controls
            HStack(spacing: 10) {
                // Sort button - tap to cycle through options
                Button(action: {
                    SoundManager.playSound(1104)
                    let allCases = SortOption.allCases
                    if let currentIndex = allCases.firstIndex(of: sortOption) {
                        let nextIndex = (currentIndex + 1) % allCases.count
                        sortOption = allCases[nextIndex]
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                        Text(sortOption.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
                
                // Filter button - tap to cycle through options
                Button(action: {
                    SoundManager.playSound(1104)
                    let allCases = FilterOption.allCases
                    if let currentIndex = allCases.firstIndex(of: filterOption) {
                        let nextIndex = (currentIndex + 1) % allCases.count
                        filterOption = allCases[nextIndex]
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text(filterOption.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }

                // Inline search box
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    if !searchText.isEmpty {
                        Button {
                            SoundManager.playSound(1104)
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .frame(minWidth: 140)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredAndSortedStats) { cat in
                    // Stable color choice by category name hash to avoid churn on re-sorts
                    let idx = abs(cat.name.hashValue) % gradientPairs.count
                    let colors = gradientPairs[idx]
                    let isComplete = cat.percent == 100
                    NavigationLink(destination: CategoryWordsView(category: cat.name)) {
                        ZStack {
                            // Transparent background card
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.clear)
                            
                            // Thin progress ring overlay (all categories)
                            Circle()
                                .trim(from: 0, to: CGFloat(cat.percent) / 100.0)
                                .stroke(
                                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .padding(8)
                            
                            // Content with enhanced hierarchy
                            VStack(spacing: 8) {
                                // Crown icon for 100% completion (top)
                                if isComplete {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.yellow)
                                        .shadow(color: .orange, radius: 2)
                                }
                                
                                // Category name
                                Text(cat.name)
                                    .font(.system(size: 20, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text("\(cat.completed)/\(cat.total)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .opacity(0.9)
                                
                                Text("\(cat.percent)% Done")
                                    .font(.system(size: 13, weight: .medium))
                                    .opacity(0.7)
                            }
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(12)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        // Lighter shadow to reduce GPU cost
                        .shadow(color: (isComplete ? colors.first! : .black).opacity(0.25), radius: 4, x: 0, y: 0)
                        .scaleEffect(tappedCategory == cat.name ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: tappedCategory)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                tappedCategory = cat.name
                            }
                            .onEnded { _ in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    tappedCategory = nil
                                }
                            }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
                .background(Color(uiColor: .systemBackground))
        .navigationTitle("Categories \(viewModel.stats.count)")
        .withNotificationBell()
        .task { viewModel.load() }
        // Avoid implicit animations when stats refresh
        .animation(nil, value: viewModel.stats)
    }
}

#Preview {
    VocabCategoryView()
}
