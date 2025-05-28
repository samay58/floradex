import SwiftUI
import PhotosUI
import SwiftData

struct IdentifyLandingView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    @EnvironmentObject private var imageService: ImageSelectionService
    @StateObject private var permissions = PermissionsManager.shared

    // Single presentation state to prevent conflicts
    @State private var presentationState: PresentationState = .none
    
    enum PresentationState {
        case none
        case photoPicker
        case camera
        case urlEntry
        case details
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selected Image Preview Section
                if let selectedImage = imageService.selectedImage {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(Theme.Metrics.cornerRadiusMedium)
                            .padding()
                        
                        Button {
                            imageService.selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.Colors.iconPrimary)
                                .background(Circle().fill(Theme.Colors.systemBackground.opacity(0.6)))
                                .padding(Theme.Metrics.Padding.medium) // Adjusted padding
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.badge.plus.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(Theme.Colors.iconSecondary)
                            .padding(.bottom, Theme.Metrics.Padding.small)
                        Text("Select an image to identify")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                    }
                    .frame(maxHeight: 250) // Ensure consistent height with image preview
                    .padding()
                }

                // Icon Buttons
                optionButtonsSection
                
                Spacer()
                Spacer() // Add more space to push button down

                // Identify Button (enabled if an image is selected)
                identifyButtonSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.systemBackground)
            .navigationTitle("Identify")
            .navigationBarItems(trailing: helpButton)
            .sheet(isPresented: Binding(
                get: { presentationState == .photoPicker },
                set: { if !$0 { presentationState = .none } }
            )) {
                PhotoPickerView()
                    .environmentObject(imageService)
            }
            .fullScreenCover(isPresented: Binding(
                get: { presentationState == .camera },
                set: { if !$0 { presentationState = .none } }
            )) {
                CameraCaptureView()
                    .environmentObject(imageService)
            }
            .sheet(isPresented: Binding(
                get: { presentationState == .urlEntry },
                set: { if !$0 { presentationState = .none } }
            )) {
                ImageURLEntryView { urlString in
                    Task {
                        await downloadImageFromURL(urlString)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { presentationState == .details },
                set: { 
                    if !$0 { 
                        presentationState = .none
                        // Clear the selected image when details view is dismissed
                        imageService.selectedImage = nil
                        viewModel.cleanup()
                    }
                }
            )) {
                if let image = imageService.selectedImage {
                    PlantDetailsView(viewModel: viewModel, identifiedImage: image)
                }
            }
            .onChange(of: imageService.selectedImage) { oldValue, newValue in
                // Don't automatically show details - require user to tap Identify button
                // This prevents infinite loops and gives user control over when to process
            }
            .onChange(of: permissions.isFullyAuthorized) { oldValue, newValue in
                if newValue && presentationState == .camera {
                    // Re-trigger camera if permission was granted (already showing camera)
                } else if !newValue && presentationState == .camera {
                    presentationState = .none
                }
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear {
            // Cleanup when view disappears
            Task {
                await viewModel.cleanup()
            }
        }
    }
    
    // MARK: - View Components
    
    private var optionButtonsSection: some View {
        HStack(spacing: Theme.Metrics.Padding.large) {
            // Gallery Button
            Button {
                guard presentationState == .none else { return }
                presentationState = .photoPicker
            } label: {
                IdentifyOptionButton(iconName: "photo.on.rectangle.angled", label: "Gallery")
            }

            // Camera Button
            Button {
                guard presentationState == .none else { return }
                if permissions.isFullyAuthorized {
                    presentationState = .camera
                } else {
                    permissions.requestCameraAccess()
                }
            } label: {
                IdentifyOptionButton(iconName: "camera", label: "Camera")
            }
            
            // URL Button
            Button {
                guard presentationState == .none else { return }
                presentationState = .urlEntry
            } label: {
                IdentifyOptionButton(iconName: "link", label: "Web")
            }
        }
        .padding(.bottom, Theme.Metrics.Padding.extraLarge)
    }
    
    private var identifyButtonSection: some View {
        Button {
            if imageService.selectedImage != nil && presentationState == .none {
                presentationState = .details
            }
        } label: {
            identifyButtonLabel
        }
        .disabled(imageService.selectedImage == nil || presentationState != .none)
        .accessibilityLabel("Identify plant")
        .accessibilityHint(imageService.selectedImage != nil ? 
                           "Double tap to identify the selected plant image" : 
                           "Select an image first to enable plant identification")
        .accessibilityAddTraits(.isButton)
        .padding(.horizontal, Theme.Metrics.Padding.large)
        .padding(.bottom, Theme.Metrics.Padding.medium)
    }
    
    private var identifyButtonLabel: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            Text("Identify")
        }
        .font(Theme.Typography.button)
        .foregroundColor(.white)
        .padding(.vertical, Theme.Metrics.Padding.small + 2) // 14pt vertical
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                .fill(imageService.selectedImage != nil && presentationState == .none ? 
                      Theme.Colors.primaryGreen : Theme.Colors.iconDisabled)
        )
    }
    
    private var helpButton: some View {
        Button(action: {
            // Help action - placeholder
            print("Help tapped")
        }) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(Theme.Colors.iconPrimary)
        }
    }
    
    // Function to download image from URL
    private func downloadImageFromURL(_ urlString: String) async {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    imageService.selectedImage = image
                }
            }
        } catch {
            print("Failed to download image: \(error)")
        }
    }
}

struct IdentifyOptionButton: View {
    let iconName: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Metrics.Padding.extraSmall) {
            Image(systemName: iconName)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(Theme.Colors.primaryGreen)
                .frame(width: 64, height: 64)
                .background(Theme.Colors.systemFill)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.textSecondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Select \(label.lowercased())")
        .accessibilityHint("Double tap to choose \(label.lowercased()) as your image source")
        .accessibilityAddTraits(.isButton)
    }
}

// New view for URL input
struct ImageURLEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var urlString: String = ""
    var onSubmit: (String) -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: Theme.Metrics.Padding.large) {
                Text("Enter Image URL")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                TextField("https://example.com/plant-image.jpg", text: $urlString)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Theme.Colors.systemFill)
                    .cornerRadius(Theme.Metrics.cornerRadiusMedium)
                
                Button("Load Image") {
                    onSubmit(urlString)
                    dismiss()
                }
                .font(Theme.Typography.button)
                .foregroundColor(.white)
                .padding(.vertical, Theme.Metrics.Padding.small + 2)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadiusLarge)
                        .fill(!urlString.isEmpty ? Theme.Colors.primaryGreen : Theme.Colors.iconSecondary)
                )
                .disabled(urlString.isEmpty)

                Spacer()
            }
            .padding(Theme.Metrics.Padding.large)
            .background(Theme.Colors.systemBackground)
            .navigationTitle("Image from Web")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.primaryGreen)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#if DEBUG
struct IdentifyLandingView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(for: SpeciesDetails.self, DexEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let speciesRepo = SpeciesRepository(modelContext: container.mainContext)
        let dexRepo = DexRepository(modelContext: container.mainContext)
        let viewModel = ClassificationViewModel(speciesRepository: speciesRepo, dexRepository: dexRepo)
        
        IdentifyLandingView(viewModel: viewModel)
            .environmentObject(ImageSelectionService.shared)
    }
}
#endif 