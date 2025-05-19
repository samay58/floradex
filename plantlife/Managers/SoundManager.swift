import AVFoundation
import Combine

final class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var audioPlayer: AVAudioPlayer?
    private var appSettings: AppSettings = .shared
    private var cancellables = Set<AnyCancellable>()

    // Mute state based on AppSettings
    @Published var isMuted: Bool

    private init() {
        self.isMuted = !appSettings.soundEnabled
        
        // Observe changes to soundEnabled in AppSettings
        // Correct way to observe @Observable AppSettings requires a bit more setup if SoundManager itself is not a View or doesn't have direct access to SwiftUI's environment.
        // A simpler way for now is to check appSettings.soundEnabled directly in playSound.
        // For a more reactive approach, AppSettings would need to publish changes in a way SoundManager can subscribe without SwiftUI context, or SoundManager could be passed AppSettings.
        // However, since AppSettings is a singleton, direct access is fine.
        
        // For @Published isMuted to update if AppSettings changes elsewhere:
        // This requires AppSettings to be an ObservableObject and soundEnabled to be @Published, or use a Combine publisher.
        // Since AppSettings is now @Observable, this becomes simpler if SoundManager is used in a context that can observe it, or we use a manual sink.
        // For a non-SwiftUI singleton, we might need a more custom observation or notification pattern if AppSettings isn't directly an ObservableObject it can sink from.

        // Let's assume AppSettings.shared will be checked at playback time for simplicity for now.
        // If AppSettings were an ObservableObject, we could do:
        /*
        appSettings.$soundEnabled // Assuming soundEnabled is @Published
            .map { !$0 }
            .assign(to: &$isMuted)
        */
        // With the new @Observable, direct observation is usually done in SwiftUI views.
        // We'll manually update isMuted or just check directly.
        self.isMuted = !AppSettings.shared.soundEnabled // Initial check
        
        // Periodically check if AppSettings changed, or make AppSettings an ObservableObject to subscribe.
        // For this iteration, checking on playSound is most straightforward.
    }

    enum SoundOption: String {
        // filenames without extension, assuming .aif or .caf based on plan
        case tapWood = "tap-wood" // plan: "tap-wood.aif"
        case trash = "trash"    // plan: "trash.caf"
        case successJingle = "success-jingle" // plan: "8-bit jingle"
        // Add other sounds here
    }

    func playSound(_ sound: SoundOption, volume: Float = 1.0) {
        // Update mute state from settings first
        self.isMuted = !AppSettings.shared.soundEnabled
        
        guard !isMuted else {
            // print("SoundManager is muted.")
            return
        }

        // Determine extension based on plan, or try multiple
        var soundFileName = sound.rawValue
        var soundUrl: URL?

        if let url = Bundle.main.url(forResource: soundFileName, withExtension: "aif") {
            soundUrl = url
        } else if let url = Bundle.main.url(forResource: soundFileName, withExtension: "caf") {
            soundUrl = url
        } else if let url = Bundle.main.url(forResource: soundFileName, withExtension: "mp3") { // Common fallback
             soundUrl = url
        } else if let url = Bundle.main.url(forResource: soundFileName, withExtension: "wav") { // Common fallback
             soundUrl = url
        }
        
        guard let url = soundUrl else {
            print("Sound file \(sound.rawValue) not found with extensions aif, caf, mp3, wav.")
            return
        }

        do {
            // Configure audio session for playback, allowing mixing with other audio
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            // print("Playing sound: \(sound.rawValue)")
        } catch {
            print("Error playing sound \(sound.rawValue): \(error.localizedDescription)")
        }
    }
    
    // Call this to update mute state if SoundManager is kept alive and AppSettings could change
    func refreshMuteState() {
        self.isMuted = !AppSettings.shared.soundEnabled
    }
} 