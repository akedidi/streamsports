import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var expandedEvents: Set<String> = []
    
    // Custom Colors
    let bgDark = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationView {
                TabView {
                    // Tab 1: Sports Events (Default)
                    ZStack {
                        bgDark.edgesIgnoringSafeArea(.all)
                        if viewModel.isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            List {
                                if !viewModel.groupedEvents.isEmpty {
                                    Section(header: Text("Upcoming & Live").font(.headline)) {
                                        ForEach(viewModel.groupedEvents) { group in
                                            if group.channels.count == 1 {
                                                // Direct Entry
                                                Button(action: {
                                                    PlayerManager.shared.play(channel: group.channels[0])
                                                }) {
                                                    EventRow(group: group, expandAction: {}, isExpanded: false)
                                                }
                                            } else {
                                                // Expandable
                                                EventRow(group: group, expandAction: {
                                                    toggleExpansion(group.id)
                                                }, isExpanded: expandedEvents.contains(group.id))
                                            }
                                        }
                                    }
                                } else {
                                    Text("No events found")
                                        .foregroundColor(.gray)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    .navigationTitle("Sports Events")
                    .tabItem {
                        Image(systemName: "sportscourt")
                        Text("Events")
                    }
                    
                    // Tab 2: TV Channels
                    ZStack {
                        bgDark.edgesIgnoringSafeArea(.all)
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            List(viewModel.channels) { channel in
                                Button(action: {
                                    PlayerManager.shared.play(channel: channel)
                                }) {
                                    ChannelRow(channel: channel)
                                }
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    .navigationTitle("TV Channels")
                    .tabItem {
                        Image(systemName: "tv")
                        Text("Channels")
                    }
                }
                .accentColor(.blue)
                .onAppear {
                    viewModel.loadData()
                }
                // Force dark mode look
                .preferredColorScheme(.dark)
            }
            
            // Global Player Overlay
            CustomPlayerOverlay()
        }
    }
    
    func toggleExpansion(_ id: String) {
        if expandedEvents.contains(id) {
            expandedEvents.remove(id)
        } else {
            expandedEvents.insert(id)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
