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
            
            // Custom Tab Bar (Placed BEFORE Player overlay)
            // Show TabBar if: 1. Not Playing, OR 2. Is Mini Player
            // Hide TabBar ONLY if: Playing AND Full Screen (Not Mini)
            if !PlayerManager.shared.isPlaying || PlayerManager.shared.isMiniPlayer {
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Global Player (Top of ZStack)
            CustomPlayerOverlay()
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
            
            // Country Filter (Menu / ComboBox)
            HStack {
                Text("COUNTRY")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                
                Spacer()
                
                Menu {
                    Button("All Countries", action: { viewModel.selectedCountry = nil })
                    ForEach(viewModel.availableCountries, id: \.self) { countryCode in
                        Button(action: { viewModel.selectedCountry = countryCode }) {
                            HStack {
                                Text(countryName(from: countryCode))
                                if viewModel.selectedCountry == countryCode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedCountry != nil ? countryName(from: viewModel.selectedCountry!) : "All")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)     // Added spacing from Search Bar
            .padding(.bottom, 15)
            
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
    func countryName(from code: String) -> String {
        let identifier = Locale(identifier: "en_US")
        return identifier.localizedString(forRegionCode: code) ?? code.uppercased()
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
