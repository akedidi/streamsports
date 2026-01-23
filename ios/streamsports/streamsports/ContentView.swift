import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var expandedEvents: Set<String> = []
    @State private var selectedTab: Int = 0 // 0: Events, 1: Channels
    
    // Custom Colors
    let bgDark = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Content
            Group {
                if selectedTab == 0 {
                    EventsView(viewModel: viewModel, expandedEvents: $expandedEvents, toggleExpansion: toggleExpansion)
                } else {
                    ChannelsView(viewModel: viewModel)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 60) // Space for TabBar
            
            // Global Player
            CustomPlayerOverlay()
            
            // Custom Tab Bar (Only show if not mini player to avoid overlap issues, OR allow overlap)
            // User requested better tab bar. We'll stick it to bottom.
            if !PlayerManager.shared.isMiniPlayer { // Hide tab bar when mini player is active? No, usually mini player sits ABOVE tab bar.
                // But for simplicity in this ZStack architecture, let's put TabBar at very bottom
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .background(bgDark.edgesIgnoringSafeArea(.all))
        .onAppear {
            viewModel.loadData()
        }
        .preferredColorScheme(.dark)
    }
    
    func toggleExpansion(_ id: String) {
        if expandedEvents.contains(id) {
            expandedEvents.remove(id)
        } else {
            expandedEvents.insert(id)
        }
    }
}

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
            }
        }
    }
    
    @ViewBuilder
    func eventCell(for group: GroupedEvent) -> some View {
        if group.channels.count == 1 {
            Button(action: {
                PlayerManager.shared.play(channel: group.channels[0])
            }) {
                EventRow(group: group, expandAction: {}, isExpanded: false)
            }
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

// Sub-view for Channels
struct ChannelsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            CustomSearchBar(text: $viewModel.channelSearchText)
                .padding(.top)
            
            // Country Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" Chip
                    FilterChip(title: "All", isSelected: viewModel.selectedCountry == nil) {
                        viewModel.selectedCountry = nil
                    }
                    
                    ForEach(viewModel.availableCountries, id: \.self) { country in
                        FilterChip(title: country, isSelected: viewModel.selectedCountry == country) {
                            viewModel.selectedCountry = country
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(viewModel.filteredChannels) { channel in
                    Button(action: {
                        PlayerManager.shared.play(channel: channel)
                    }) {
                        ChannelRow(channel: channel)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(UIColor.tertiarySystemFill))
                .foregroundColor(.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
