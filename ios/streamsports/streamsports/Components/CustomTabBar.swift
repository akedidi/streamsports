import SwiftUI

// Custom Tab Bar to replace standard one
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            Spacer()
            // Events Tab
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 4) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 20, weight: selectedTab == 0 ? .bold : .regular))
                    Text("Events")
                        .font(.caption2)
                }
                .foregroundColor(selectedTab == 0 ? .blue : .gray)
            }
            Spacer()
            Spacer()
            // Channels Tab
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 4) {
                    Image(systemName: "tv")
                        .font(.system(size: 20, weight: selectedTab == 1 ? .bold : .regular))
                    Text("Channels")
                        .font(.caption2)
                }
                .foregroundColor(selectedTab == 1 ? .blue : .gray)
            }
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 30) // Safe area
        .background(Color(red: 0.1, green: 0.1, blue: 0.1).edgesIgnoringSafeArea(.bottom))
    }
}
