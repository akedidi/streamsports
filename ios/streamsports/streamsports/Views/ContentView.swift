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
        .environmentObject(viewModel)
        .onAppear {
            viewModel.loadData()
        }
        .preferredColorScheme(.dark)
    }
    
    func toggleExpansion(_ id: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if expandedEvents.contains(id) {
                expandedEvents.remove(id)
            } else {
                expandedEvents.insert(id)
            }
        }
    }
}
