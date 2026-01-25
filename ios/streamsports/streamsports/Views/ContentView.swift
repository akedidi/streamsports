import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var expandedEvents: Set<String> = []
    @State private var selectedTab: Int = 0 // 0: Events, 1: Channels
    
    @ObservedObject var playerManager = PlayerManager.shared // Observe for animation
    
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
            //.padding(.bottom, 60) // Removed for full height
            .edgesIgnoringSafeArea(.bottom)
            .padding(.bottom, (!playerManager.isPlaying || playerManager.isMiniPlayer) ? 80 : 0)
            
            // Custom Tab Bar (Placed BEFORE Player overlay)
            // Show TabBar if: 1. Not Playing, OR 2. Is Mini Player
            // Hide TabBar ONLY if: Playing AND Full Screen (Not Mini)
            if !playerManager.isPlaying || playerManager.isMiniPlayer {
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
            // Global Player (Top of ZStack)
            if playerManager.currentChannel != nil {
                CustomPlayerOverlay()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: playerManager.currentChannel != nil)
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
