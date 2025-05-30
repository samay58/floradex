import SwiftUI
import PhotosUI
import SwiftData
import Combine

struct IdentifyLandingView: View {
    @ObservedObject var viewModel: ClassificationViewModel
    @EnvironmentObject private var imageService: ImageSelectionService
    @StateObject private var permissions = PermissionsManager.shared

    // Single presentation state to prevent conflicts
    @State private var presentationState: PresentationState = .none
    
    // Animation states
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOpacity: Double = 0.0
    @State private var showEmptyState = true
    @State private var buttonBreathing = false
    
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
                            .scaleEffect(imageScale)
                            .opacity(imageOpacity)
                            .blur(radius: imageOpacity < 1 ? 10 * (1 - imageOpacity) : 0)
                            .padding()
                            .onAppear {
                                showEmptyState = false
                                withAnimation(AnimationConstants.signatureSpring) {
                                    imageScale = 1.02
                                    imageOpacity = 1.0
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(AnimationConstants.smoothSpring) {
                                        imageScale = 0.98
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(AnimationConstants.smoothSpring) {
                                            imageScale = 1.0
                                        }
                                    }
                                }
                                
                                HapticManager.shared.imageSelection()
                                buttonBreathing = true
                            }
                        
                        Button {
                            HapticManager.shared.buttonTap()
                            withAnimation(AnimationConstants.quickSpring) {
                                imageOpacity = 0.0
                                imageScale = 0.8
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                imageService.selectedImage = nil
                                showEmptyState = true
                                buttonBreathing = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(Theme.Colors.iconPrimary)
                                .background(Circle().fill(Theme.Colors.systemBackground.opacity(0.6)))
                                .padding(Theme.Metrics.Padding.medium)
                        }
                    }
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.badge.plus.fill")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(Theme.Colors.iconSecondary)
                            .padding(.bottom, Theme.Metrics.Padding.small)
                            .scaleEffect(showEmptyState ? 1.0 : 0.8)
                            .opacity(showEmptyState ? 1.0 : 0.0)
                        Text("Select an image to identify")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.textSecondary)
                            .opacity(showEmptyState ? 1.0 : 0.0)
                        Spacer()
                    }
                    .frame(maxHeight: 250)
                    .padding()
                    .onAppear {
                        withAnimation(AnimationConstants.signatureSpring.delay(0.1)) {
                            showEmptyState = true
                        }
                    }
                }

                // Icon Buttons
                optionButtonsSection
                
                Spacer()

                // Identify Button (enabled if an image is selected)
                identifyButtonSection
                    .padding(.bottom, Theme.Metrics.Padding.large) // Add bottom padding instead of multiple spacers
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
                print("Gallery button tapped, presentationState: \(presentationState)")
                guard presentationState == .none else { 
                    print("Gallery button blocked - presentationState not .none")
                    return 
                }
                HapticManager.shared.buttonTap()
                presentationState = .photoPicker
                print("Set presentationState to .photoPicker")
            } label: {
                IdentifyOptionButton(iconName: "photo.on.rectangle.angled", label: "Gallery")
            }

            // Camera Button
            Button {
                print("Camera button tapped, presentationState: \(presentationState)")
                guard presentationState == .none else { 
                    print("Camera button blocked - presentationState not .none")
                    return 
                }
                HapticManager.shared.buttonTap()
                
                // Check camera permission status
                let status = AVCaptureDevice.authorizationStatus(for: .video)
                switch status {
                case .authorized:
                    presentationState = .camera
                    print("Set presentationState to .camera")
                case .notDetermined:
                    print("Requesting camera access")
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async {
                            if granted {
                                presentationState = .camera
                                print("Camera access granted, opening camera")
                            } else {
                                print("Camera access denied")
                            }
                        }
                    }
                case .denied, .restricted:
                    print("Camera access denied or restricted - show settings alert")
                    // TODO: Show alert to go to settings
                @unknown default:
                    print("Unknown camera authorization status")
                }
            } label: {
                IdentifyOptionButton(iconName: "camera", label: "Camera")
            }
            
            // URL Button
            Button {
                print("URL button tapped, presentationState: \(presentationState)")
                guard presentationState == .none else { 
                    print("URL button blocked - presentationState not .none")
                    return 
                }
                HapticManager.shared.buttonTap()
                presentationState = .urlEntry
                print("Set presentationState to .urlEntry")
            } label: {
                IdentifyOptionButton(iconName: "link", label: "Web")
            }
        }
        .padding(.bottom, Theme.Metrics.Padding.extraLarge)
    }
    
    private var identifyButtonSection: some View {
        Button {
            if imageService.selectedImage != nil && presentationState == .none {
                HapticManager.shared.buttonTap()
                presentationState = .details
            }
        } label: {
            identifyButtonLabel
        }
        .disabled(imageService.selectedImage == nil || presentationState != .none)
        .modifier(buttonBreathing && imageService.selectedImage != nil ? 
            BreathingModifier(minScale: 0.985, maxScale: 1.015) : 
            BreathingModifier(minScale: 1.0, maxScale: 1.0))
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
            print("Help button tapped - showing help content")
            // TODO: Show help sheet or navigate to help view
        }) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(Theme.Colors.iconPrimary)
        }
        .buttonStyle(ScaleButtonStyle())
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

// Custom button style for scale animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AnimationConstants.microSpring, value: configuration.isPressed)
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