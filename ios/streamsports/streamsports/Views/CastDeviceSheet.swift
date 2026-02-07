import SwiftUI
import GoogleCast

struct CastDeviceSheet: View {
    @ObservedObject var manager = ChromecastManager.shared
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.1, green: 0.1, blue: 0.1) // Dark Gray Background
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    if manager.isConnected {
                        // Connected State
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "tv.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            Text("Connected to \(manager.devices.first?.friendlyName ?? "Device")")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button(action: {
                                manager.disconnect()
                                isPresented = false
                            }) {
                                Text("Disconnect")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            Spacer()
                        }
                    } else if manager.devices.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
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
                                        Text(device.friendlyName ?? "Unknown Device")
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .background(Color.clear) // Ensure list is transparent
                    }
                }
            }
            .navigationTitle("Cast to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
