import SwiftUI
import AVKit

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
    @State private var dragOffset: CGFloat = 0
    
    // Constants
    let miniPlayerHeight: CGFloat = 60
    let tabBarHeight: CGFloat = 50 // Approx
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer() // Pushes content down if needed, but we rely on offset
                
                if manager.currentChannel != nil {
                    ZStack(alignment: .top) {
                        // Background (Full Screen Card)
                        if !manager.isMiniPlayer {
                            Color(UIColor.systemBackground) // Or dark gray
                                .cornerRadius(20, corners: [.topLeft, .topRight])
                                .shadow(radius: 10)
                                .edgesIgnoringSafeArea(.all)
                                .onTapGesture {
                                    // Consume taps to prevent closing if we had a background dimmer
                                }
                        }
                        
                        // Content
                        VStack(spacing: 0) {
                            // 1. Handle / Top Bar (Only in Full)
                            if !manager.isMiniPlayer {
                                Capsule()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 10)
                                    .padding(.bottom, 10)
                            }
                            
                            // 2. Video Area (16:9 aspect ratio consistent)
                            ZStack {
                                Color.black
                                
                                if let player = manager.player {
                                    VideoPlayer(player: player)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }
                            .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.width * 9/16)
                            .frame(maxWidth: manager.isMiniPlayer ? 100 : .infinity, alignment: .leading)
                            
                            // 3. Info & Controls (Full Screen Only)
                            if !manager.isMiniPlayer {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        // Header
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(manager.currentChannel?.name ?? "Loading...")
                                                .font(.title2).bold()
                                                .foregroundColor(.primary) // Auto dark/light
                                            Text(manager.currentChannel?.match_info ?? "")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.top)
                                        
                                        // Controls Grid
                                        HStack(spacing: 0) {
                                            ControlButton(icon: "airplayvideo", label: "AirPlay") {
                                                // AirPlay Picker logic (requires AVRoutePickerView wrapper)
                                            }
                                            Spacer()
                                            ChromecastButton().frame(width: 30, height: 30) // Use wrapper
                                            Spacer() 
                                            ControlButton(icon: "arrow.up.left.and.arrow.down.right", label: "Full") {
                                                // Toggle UI hidden
                                            }
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(12)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                        }
                        
                        // 4. Mini Player Info Overlay (Only in Mini)
                        if manager.isMiniPlayer {
                            HStack {
                                Spacer().frame(width: 110) // Gap for video
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(manager.currentChannel?.name ?? "Loading...")
                                        .font(.subheadline).bold()
                                        .lineLimit(1)
                                    Text("Tap to expand")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                // Mini Controls
                                Button(action: { manager.togglePlayPause() }) {
                                    Image(systemName: manager.player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                        .font(.title2)
                                        .padding()
                                }
                                
                                Button(action: { manager.close() }) {
                                    Image(systemName: "xmark")
                                        .padding()
                                }
                            }
                            .frame(height: miniPlayerHeight)
                            .background(Color(UIColor.secondarySystemBackground))
                            .overlay(Divider(), alignment: .top)
                        }
                    }
                    // Layout Logic
                    .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.height)
                    .offset(y: manager.isMiniPlayer ? -60 : max(0, dragOffset)) // -60 to sit above tabbar? 
                    // Actually, if we use ZStack in ContentView properly, we can just align .bottom
                    .gesture(
                        DragGesture().onChanged { value in
                            if !manager.isMiniPlayer && value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }.onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.spring()) {
                                    manager.isMiniPlayer = true
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                    )
                    .onTapGesture {
                        if manager.isMiniPlayer {
                            withAnimation(.spring()) {
                                manager.isMiniPlayer = false
                            }
                        }
                    }
                }
            }
        }
        // This view is placed in a ZStack in ContentView. 
        // We want it blocked at the bottom for mini player.
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label).font(.caption)
            }
            .frame(width: 80)
            .foregroundColor(.primary)
        }
    }
}

// Extension for partial corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
