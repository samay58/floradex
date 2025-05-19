import XCTest
@testable import plantlife // Ensure your main app module is importable
import ActivityKit

// Mock ImageSelectionService for testing ClassificationViewModel
class MockImageSelectionService: ImageSelectionService {
    override init() {
        super.init()
    }
    // We can publish a selectedImage to trigger the pipeline in tests
    func triggerImageSelection(_ image: UIImage) {
        self.selectedImage = image
    }
}

// Mock repositories if needed for controlled testing, or use in-memory versions
// For simplicity, we might rely on their actual implementations if they don't have heavy dependencies.

@MainActor
final class LiveActivityTests: XCTestCase {

    var viewModel: ClassificationViewModel!
    var mockImageService: MockImageSelectionService!
    var mockSpeciesRepository: SpeciesRepository! // Assuming an in-memory or mock version can be provided
    var mockDexRepository: DexRepository!       // Assuming an in-memory or mock version can be provided
    var appSettings: AppSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        appSettings = AppSettings.shared
        
        // Ensure Live Activities are enabled for these tests
        appSettings.isLiveActivityEnabled = true
        
        // Setup in-memory repositories or mocks
        // For this example, assuming SpeciesRepository and DexRepository can be initialized for testing
        // (e.g., with an in-memory SwiftData store or specific test configurations)
        mockSpeciesRepository = SpeciesRepository(modelContainer: PersistenceController.preview.container) // Example
        mockDexRepository = DexRepository(modelContainer: PersistenceController.preview.container)       // Example
        
        mockImageService = MockImageSelectionService()
        viewModel = ClassificationViewModel(
            imageService: mockImageService,
            speciesRepository: mockSpeciesRepository,
            dexRepository: mockDexRepository
        )
        
        // Mock ActivityAuthorizationInfo().areActivitiesEnabled if possible, or ensure it's true in test environment
        // This is harder to mock directly without more advanced techniques.
        // For now, tests will assume it's enabled or fail gracefully if not.
    }

    override func tearDownWithError() throws {
        viewModel = nil
        mockImageService = nil
        mockSpeciesRepository = nil
        mockDexRepository = nil
        appSettings.isLiveActivityEnabled = false // Reset flag
        ActivityStubs.removeAllStubs()
        try super.tearDownWithError()
    }

    func testLiveActivityLifecycle_SuccessPath() async throws {
        // Ensure activities are authorized for this test to run meaningfully
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw XCTSkip("Live Activities not enabled in this environment.")
        }
        
        // 1. Stub Activity.request to capture the activity and its updates
        var startedActivity: Activity<PlantIdentificationActivityAttributes>?
        var activityUpdates: [PlantIdentificationActivityAttributes.ContentState] = []

        ActivityStubs.requestStub = { attributes, contentState, pushType in
            let activity = Activity<PlantIdentificationActivityAttributes>.makeStub(
                attributes: attributes,
                contentState: contentState
            )
            startedActivity = activity
            activityUpdates.append(contentState)
            return activity
        }
        
        ActivityStubs.updateStub = { activity, contentState, alertConfiguration in 
            // Type-erase activity to match the stub signature, then cast back if needed for inspection
            if let castedActivity = activity as? Activity<PlantIdentificationActivityAttributes>,
               castedActivity.id == startedActivity?.id {
                activityUpdates.append(contentState)
            }
        }
        
        ActivityStubs.endStub = { activity, contentState, dismissalPolicy in
             if let castedActivity = activity as? Activity<PlantIdentificationActivityAttributes>,
               castedActivity.id == startedActivity?.id {
                activityUpdates.append(contentState)
             }
        }

        // 2. Trigger the pipeline (e.g., by setting an image)
        // Use a small, simple UIImage for testing to avoid heavy processing
        let testImage = UIImage(systemName: "photo") ?? UIImage()
        mockImageService.triggerImageSelection(testImage)

        // 3. Wait for the pipeline to complete (it's async)
        // This requires a way to know when viewModel.runPipeline has finished.
        // For simplicity, we'll use an expectation or a short sleep, but in a real scenario,
        // you might observe viewModel.isLoading or use specific async expectations.
        let expectation = XCTestExpectation(description: "Pipeline completion")
        // A more robust way would be to chain off a publisher from the VM or use a delegate.
        // For now, using a slight delay and checking isLoading.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { // Adjust timeout as needed
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 6.0)

        // 4. Assertions
        XCTAssertNotNil(startedActivity, "Live Activity should have been started.")
        XCTAssertFalse(activityUpdates.isEmpty, "Live Activity should have received updates.")

        // Check initial phase
        XCTAssertEqual(activityUpdates.first?.phase, .searching, "Initial phase should be searching.")

        // Check for other phases (example, this depends on the mocked pipeline behavior)
        // This part is tricky because the actual classification services are not mocked here.
        // A more thorough test would mock ClassifierService, GPT4oService, etc.
        XCTAssertTrue(activityUpdates.contains(where: { $0.phase == .analyzing }), "Should have an analyzing phase update.")
        // XCTAssertTrue(activityUpdates.contains(where: { $0.phase == .done || $0.phase == .failed }), "Activity should end in done or failed state.")

        if let lastUpdate = activityUpdates.last {
            XCTAssertTrue(lastUpdate.phase == .done || lastUpdate.phase == .failed, "Final phase should be done or failed.")
            if lastUpdate.phase == .done {
                XCTAssertNotNil(lastUpdate.commonName, "Common name should be present on success.")
            }
        }
        
        // Check if activity was ended (currentActivity in VM should be nil)
        XCTAssertNil(viewModel.currentActivity, "Current activity in VM should be nil after pipeline completion.")
    }
    
    func testLiveActivity_FeatureDisabled() async {
        appSettings.isLiveActivityEnabled = false
        var didAttemptToStart = false
        ActivityStubs.requestStub = { _, _, _ in
            didAttemptToStart = true
            throw TestError.stubCalled
        }

        let testImage = UIImage(systemName: "photo") ?? UIImage()
        mockImageService.triggerImageSelection(testImage)
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertFalse(didAttemptToStart, "Should not attempt to start Live Activity if feature is disabled.")
        XCTAssertNil(viewModel.currentActivity, "Current activity should be nil.")
    }
}

// Helper for stubbing ActivityKit calls (basic version)
// In a real project, you might use a more robust mocking library or approach.
enum ActivityStubs {
    static var requestStub: ((Any, Any, Any?) throws -> Any)? // (attributes, contentState, pushType) -> Activity
    static var updateStub: ((Any, Any, Any?) async -> Void)?    // (activity, contentState, alertConfiguration)
    static var endStub: ((Any, Any, Any) async -> Void)?       // (activity, contentState, dismissalPolicy)

    static func removeAllStubs() {
        requestStub = nil
        updateStub = nil
        endStub = nil
    }
}

// Extend Activity to allow stubbing (simplistic)
// This is a very basic way to intercept calls; proper mocking is complex.
extension Activity {
    static func makeStub<Attributes: ActivityAttributes>(attributes: Attributes, contentState: Attributes.ContentState) -> Activity<Attributes> {
        // This is problematic because initializer is internal. 
        // Real testing often involves protocol-based mocking or more advanced techniques.
        // For the purpose of this sketch, we assume we can create a test instance or that the
        // `requestStub` itself handles the creation and returns an `Activity` instance we can track.
        // This part highlights the difficulty of mocking ActivityKit directly without OS support or internal access.
        
        // A workaround for testing logic *around* ActivityKit is to check if your ViewModel *would* call it,
        // rather than fully mocking the Activity object itself.
        
        // Fallback: If we cannot create a real Activity, the stubs become more about tracking call attempts.
        fatalError("makeStub needs a way to create a test Activity instance or stubs should handle this.")
    }
}

enum TestError: Error {
    case stubCalled
}

// You would also need to ensure that your project settings allow testing for the main app target (`plantlife`).
// And if PlantIdentificationActivityAttributes is in a separate module, that module should also be testable.

// To make PersistenceController.preview available, you might need to ensure it's part of the test target
// or provide a test-specific PersistenceController.
// For example, in PersistenceController.swift:
// #if DEBUG
// static var preview: PersistenceController = {
//    let controller = PersistenceController(inMemory: true)
//    // ... setup sample data ...
//    return controller
// }()
// #endif 