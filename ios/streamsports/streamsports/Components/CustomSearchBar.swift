import SwiftUI

struct CustomSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    @StateObject private var chromecastManager = ChromecastManager.shared
    @State private var showCastSheet = false

    var body: some View {
        HStack(spacing: 12) {
            // Search Bar Container
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            
            // Cast Button (Always Visible)
            Button(action: {
                showCastSheet = true
            }) {
                Image("ChromecastIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(chromecastManager.isConnected ? .blue : .white)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .sheet(isPresented: $showCastSheet) {
                CastDeviceSheet(isPresented: $showCastSheet)
                    .presentationDetents([.medium]) // iOS 16+ Half Sheet
                    .presentationDragIndicator(.visible)
            }
        }
        .padding(.horizontal)
    }
}
