import SwiftUI
import GoogleCast

struct CastDeviceSheet: View {
    @ObservedObject var manager = ChromecastManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if manager.devices.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Searching for devices...")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(manager.devices, id: \.deviceID) { device in
                            Button(action: {
                                manager.connect(to: device)
                                isPresented = false
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "tv")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading) {
                                        Text(device.friendlyName ?? "Unknown Device")
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.clear)
                        }
                        
                        // Always show spinner at the bottom
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.gray)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color(white: 0.1).edgesIgnoringSafeArea(.all))
            .navigationTitle("Cast to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
