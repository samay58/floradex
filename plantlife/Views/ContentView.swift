import SwiftUI
import SwiftData // For preview context
import PhotosUI
import AVFoundation // For camera permissions

struct ContentView: View {
    @StateObject private var viewModel: ClassificationViewModel
    @EnvironmentObject private var imageService: ImageSelectionService
    @StateObject private var permissions = PermissionsManager.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingInfoSheet = false
    @State private var showingPermissionsOverlay = false
    @State private var appearAnimation = false
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastImageOffset: CGSize = .zero
    @State private var isDragging = false

    init(viewModel: ClassificationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top toolbar
                GlassToolbar(style: .top) {
                    HStack {
                        Button {
                            withAnimation(Theme.Animations.snappy) {
                                showingInfoSheet.toggle()
                            }
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: Theme.Metrics.iconSize, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Text("PlantLife")
                            .font(Theme.Typography.title3)
                        
                        Spacer()
                        
                        PhotosPicker(selection: $selectedItem,
                                   matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: Theme.Metrics.iconSize, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal)
                }
                
                // Main content
                GeometryReader { geometry in
                    ZStack {
                        if let image = viewModel.imageService.selectedImage {
                            // Image view with zoom and pan
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(imageScale)
                                .offset(imageOffset)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            imageScale = value.magnitude
                                        }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            isDragging = true
                                            imageOffset = CGSize(
                                                width: lastImageOffset.width + value.translation.width,
                                                height: lastImageOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            isDragging = false
                                            lastImageOffset = imageOffset
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(Theme.Animations.snappy) {
                                        if imageScale > 1 {
                                            imageScale = 1
                                            imageOffset = .zero
                                            lastImageOffset = .zero
                                        } else {
                                            imageScale = 2
                                        }
                                    }
                                }
                                .opacity(appearAnimation ? 1 : 0)
                                .scaleEffect(appearAnimation ? 1 : 0.8)
                                .animation(Theme.Animations.smooth, value: appearAnimation)
                        } else {
                            // Empty state
                            VStack(spacing: Theme.Metrics.Padding.medium) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(Theme.Colors.secondary)
                                    .opacity(0.5)
                                
                                Text("Take a photo or select an image to identify a plant")
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundStyle(Theme.Colors.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(Theme.Animations.smooth, value: appearAnimation)
                        }
                        
                        // Loading overlay
                        if viewModel.isLoading {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(.white)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Bottom card
                if let species = viewModel.species {
                    InfoCardView(
                        species: species,
                        confidence: viewModel.confidence,
                        details: viewModel.details,
                        isLoading: viewModel.isLoading
                    )
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(
                Button {
                    withAnimation(Theme.Animations.snappy) {
                        showingCamera = true
                    }
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28, weight: .medium))
                }
                .circularButton(size: 70, backgroundColor: Theme.Colors.primary, foregroundColor: .white, hasBorder: false)
                .padding(.trailing, 24)
                .padding(.bottom, 40),
                alignment: .bottomTrailing
            )
            .fullScreenCover(isPresented: $showingCamera) {
                if permissions.isFullyAuthorized {
                    CameraCaptureView()
                        .environmentObject(ImageSelectionService.shared)
                } else {
                    PermissionsOverlayView()
                        .environmentObject(permissions)
                }
            }
        }
        .sheet(isPresented: $showingInfoSheet) {
            InfoSheetView(
                image: viewModel.imageService.selectedImage ?? UIImage(systemName: "leaf.fill")!,
                classifierVM: viewModel
            )
        }
        .onChange(of: selectedItem) { _ in
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.imageService.selectedImage = image
                }
            }
        }
        .onAppear {
            withAnimation(Theme.Animations.smooth.delay(0.1)) {
                appearAnimation = true
            }
        }
    }
}

#Preview("No Image Selected") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SpeciesDetails.self, DexEntry.self, configurations: config)
    let speciesRepo = SpeciesRepository(modelContext: container.mainContext)
    let dexRepo = DexRepository(modelContext: container.mainContext)
    let imageService = ImageSelectionService.shared
    imageService.selectedImage = nil // Ensure no image is selected

    return NavigationStack {
        ContentView(viewModel: ClassificationViewModel(speciesRepository: speciesRepo, dexRepository: dexRepo))
        .environmentObject(imageService)
        .modelContainer(container)
    }
}

#Preview("Image Selected") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SpeciesDetails.self, DexEntry.self, configurations: config)
    let speciesRepo = SpeciesRepository(modelContext: container.mainContext)
    let dexRepo = DexRepository(modelContext: container.mainContext)
    let imageService = ImageSelectionService.shared
    // Use the same helper we created for InfoSheetView previews for a consistent placeholder
    imageService.selectedImage = PreviewHelpers.previewImage 

    return NavigationStack {
        ContentView(viewModel: ClassificationViewModel(speciesRepository: speciesRepo, dexRepository: dexRepo))
        .environmentObject(imageService)
        .modelContainer(container)
    }
} 