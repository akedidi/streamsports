import SwiftUI

// Sub-view for Events to keep ContentView clean
struct EventsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var expandedEvents: Set<String>
    var toggleExpansion: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            CustomSearchBar(text: $viewModel.searchText)
                .padding(.top)
                .padding(.bottom, 8)
            
            // Category Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.availableCategories, id: \.self) { category in
                        FilterChip(
                            title: category == "All" ? "All Sports" : category,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            
            if viewModel.isLoading {
                Spacer()
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                Spacer()
            } else {
                List {
                    // LIVE Section
                    if !viewModel.liveEvents.isEmpty {
                        Section(header: Text("LIVE NOW").font(.headline).foregroundColor(.red)) {
                            ForEach(viewModel.liveEvents) { group in
                                eventCell(for: group)
                            }
                        }
                    }
                    
                    // UPCOMING Section
                    if !viewModel.upcomingEvents.isEmpty {
                        Section(header: Text("UPCOMING").font(.headline).foregroundColor(.blue)) {
                            ForEach(viewModel.upcomingEvents) { group in
                                eventCell(for: group)
                            }
                        }
                    } else if viewModel.liveEvents.isEmpty {
                        Text("No upcoming events found right now.")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .listStyle(PlainListStyle())
                .edgesIgnoringSafeArea(.bottom)
                .refreshable {
                    await viewModel.reload()
                }
                
                // Spacer removed (handled by content padding)
            }
        }
    }
    
    @ViewBuilder
    func eventCell(for group: GroupedEvent) -> some View {
        if group.channels.count == 1 {
            // Pass the play action directly to the EventRow's internal Button
            EventRow(group: group, expandAction: {
                PlayerManager.shared.play(channel: group.channels[0])
            }, isExpanded: false)
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color.white.opacity(0.1))
        } else {
            EventRow(group: group, expandAction: {
                toggleExpansion(group.id)
            }, isExpanded: expandedEvents.contains(group.id))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color.white.opacity(0.1))
        }
    }
}
