import SwiftUI

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
            .padding(.top, 10)
            .padding(.bottom, 15)
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List(viewModel.filteredChannels) { channel in
                    Button(action: {
                        PlayerManager.shared.play(channel: channel, source: .channelList)
                    }) {
                        ChannelRow(channel: channel)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(PlainListStyle())
                .edgesIgnoringSafeArea(.bottom)
                .refreshable {
                    await viewModel.reload()
                }
                
                // Spacer for Mini Player & Tab Bar
                Color.clear.frame(height: 160)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
    }
    
    func countryName(from code: String) -> String {
        let identifier = Locale(identifier: "en_US")
        return identifier.localizedString(forRegionCode: code) ?? code.uppercased()
    }
}
