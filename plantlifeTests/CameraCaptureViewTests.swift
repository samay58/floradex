import XCTest
import SwiftUI
import SnapshotTesting
@testable import plantlife

class CameraCaptureViewTests: XCTestCase {
    
    // Helper for creating a mock camera view for testing
    private func createMockCameraView() -> some View {
        // Create a mock version of CameraCaptureView that doesn't use real camera
        struct MockCameraCaptureView: View {
            @Environment(\.dismiss) private var dismiss
            @State private var isFlashEnabled: Bool = false
            @State private var appearedAnimation: Bool = true // Start with animation completed
            
            var body: some View {
                ZStack {
                    // Black background for full-screen effect
                    Color.black.ignoresSafeArea()
                    
                    GeometryReader { geometry in
                        VStack {
                            // GlassBar for controls
                            GlassBar {
                                HStack {
                                    Button {
                                        // Mock dismiss
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    .circularButton(
                                        size: 44,
                                        backgroundColor: .black.opacity(0.5),
                                        foregroundColor: .white,
                                        hasBorder: false
                                    )
                                    
                                    Spacer()
                                    
                                    Button {
                                        // Mock flash toggle
                                        isFlashEnabled.toggle()
                                    } label: {
                                        Image(systemName: isFlashEnabled ? "bolt.fill" : "bolt.slash")
                                    }
                                    .circularButton(
                                        size: 44,
                                        backgroundColor: .black.opacity(0.5),
                                        foregroundColor: isFlashEnabled ? .yellow : .white,
                                        hasBorder: false
                                    )
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top)
                            
                            Spacer()
                            
                            // Centered camera preview with GameBoy frame
                            ZStack {
                                GameBoyCameraFrame {
                                    // Instead of real camera, use a mock display
                                    ZStack {
                                        Color.gray.opacity(0.8)
                                        
                                        VStack {
                                            Text("Camera Preview")
                                                .foregroundColor(.white)
                                                .font(.title2)
                                            
                                            Image(systemName: "camera.viewfinder")
                                                .font(.system(size: 48))
                                                .foregroundColor(.white)
                                                .padding()
                                        }
                                    }
                                }
                                .frame(maxWidth: geometry.size.width)
                            }
                            .frame(maxHeight: .infinity)
                            
                            // Shutter button at bottom
                            HStack {
                                Spacer()
                                
                                PixelButton(style: .primary, icon: "circle.fill") {
                                    // Mock capture
                                }
                                .padding(.bottom, 30)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        
        return MockCameraCaptureView()
    }
    
    func testCameraCaptureView() throws {
        // Create mock view for testing
        let mockView = createMockCameraView()
            .frame(width: 390, height: 844) // iPhone 13 dimensions
        
        // Test in light mode
        let lightVC = UIHostingController(rootView: mockView.preferredColorScheme(.light))
        assertSnapshot(matching: lightVC, as: .image(on: .iPhoneX))
        
        // Test in dark mode
        let darkVC = UIHostingController(rootView: mockView.preferredColorScheme(.dark))
        assertSnapshot(matching: darkVC, as: .image(on: .iPhoneX))
    }
} 