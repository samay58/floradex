import XCTest
import SwiftUI
import SnapshotTesting
@testable import plantlife

class UIComponentsTests: XCTestCase {
    
    func testGameBoyCameraFrame() throws {
        // Create a test view with GameBoyCameraFrame
        let view = GameBoyCameraFrame {
            Color.gray
                .overlay(
                    Text("Camera Preview")
                        .foregroundColor(.white)
                )
        }
        .frame(width: 320, height: 480)
        .background(Color.black)
        
        // Test light mode
        let lightVC = UIHostingController(rootView: view.preferredColorScheme(.light))
        assertSnapshot(matching: lightVC, as: .image(on: .iPhoneX))
        
        // Test dark mode
        let darkVC = UIHostingController(rootView: view.preferredColorScheme(.dark))
        assertSnapshot(matching: darkVC, as: .image(on: .iPhoneX))
    }
    
    func testDexCardPager() throws {
        // Create mock cards for testing
        struct TestCard: View, DexDetailCard {
            let id: Int
            let title: String
            let color: Color
            
            var accentColor: Color { color }
            
            var body: some View {
                VStack {
                    Text(title)
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                    
                    Rectangle()
                        .fill(color.opacity(0.5))
                        .overlay(
                            Text("Card \(id)")
                                .font(.title)
                                .foregroundColor(.white)
                        )
                }
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(16)
                .padding()
            }
        }
        
        let testCards = [
            AnyDexDetailCard(TestCard(id: 0, title: "Overview", color: .blue)),
            AnyDexDetailCard(TestCard(id: 1, title: "Care", color: .green)),
            AnyDexDetailCard(TestCard(id: 2, title: "Growth", color: .orange))
        ]
        
        // Initial pager state
        let pager = DexCardPager(cards: testCards)
            .frame(width: 320, height: 480)
            .background(Color.gray.opacity(0.2))
        
        let vc = UIHostingController(rootView: pager)
        assertSnapshot(matching: vc, as: .image(on: .iPhoneX))
        
        // Test with simulated drag
        // Note: for a more complete test, we would need ViewInspector or UI tests
        // to interact with the gesture, which is beyond the scope of this snapshot test.
    }
    
    func testPixelPageDots() throws {
        // Test page dots in different states
        let dotView = VStack(spacing: 20) {
            PixelPageDots(count: 3, current: 0)
                .padding()
                .background(Color.white)
            
            PixelPageDots(count: 3, current: 1)
                .padding()
                .background(Color.white)
            
            PixelPageDots(count: 3, current: 2)
                .padding()
                .background(Color.white)
            
            PixelPageDots(count: 5, current: 2)
                .padding()
                .background(Color.white)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .frame(width: 300, height: 400)
        
        let vc = UIHostingController(rootView: dotView)
        assertSnapshot(matching: vc, as: .image(on: .iPhoneX))
    }
} 