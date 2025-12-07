import Foundation
import WhisperKit
import AVFoundation

class WhisperManager: ObservableObject, SpeechBufferDelegate {
    
    @Published var isModelLoaded = false
    @Published var currentText = "" // Making this the "Finalized" text
    @Published var partialText = "" // The current in-progress text
    @Published var audioLevel: Float = 0.0
    
    private var whisperKit: WhisperKit?
    private var bufferManager = SpeechBufferManager()
    
    // Serial queue to prevent inference overlaps
    private let inferenceQueue = DispatchQueue(label: "com.translationapp.inference")
    private var isInferencing = false
    
    // User requested specific optimized model (~626MB)
    // This allows for 'Large' accuracy within the 700MB constraint.
    let modelName = "openai_whisper-large-v3-v20240930_626MB" 
    
    override init() {
        bufferManager.delegate = self
    }
    
    func setup() async {
        do {
            print("Initializing WhisperKit...")
            let pipe = try await WhisperKit(computeOptions: .init(modelName: modelName))
            DispatchQueue.main.async {
                self.whisperKit = pipe
                self.isModelLoaded = true
                print("WhisperKit loaded!")
            }
        } catch {
            print("Error loading WhisperKit: \(error)")
        }
    }
    
    func processAudio(samples: [Float]) {
        bufferManager.process(buffer: samples)
    }
    
    func resetState() {
        bufferManager.reset()
        currentText = ""
        partialText = ""
    }
    
    // MARK: - SpeechBufferDelegate
    
    func didUpdateAudioLevels(level: Float) {
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
    
    func didDetectSpeechStart() {
        // Optional: UI feedback
    }
    
    func didUpdatePartialBuffer(buffer: [Float]) {
        // Run light/fast inference for preview?
        // OR: Just wait. For "Real Time", we run it.
        // We debounce this to avoid choking the engine.
        
        guard !isInferencing else { return }
        
        inferenceQueue.async { [weak self] in
            guard let self = self, let pipe = self.whisperKit else { return }
            self.isInferencing = true
            
            do {
                // Running transcribe on current buffer
                let results = try await pipe.transcribe(audioArray: buffer)
                let text = results.text ?? ""
                
                DispatchQueue.main.async {
                    self.partialText = text
                }
            } catch {
                print(error)
            }
            
            self.isInferencing = false
        }
    }
    
    func didDetectSpeechEnd(segment: [Float]) {
        // High priority inference for final result
        inferenceQueue.async { [weak self] in
            guard let self = self, let pipe = self.whisperKit else { return }
            self.isInferencing = true // Block partials
            
            do {
                let results = try await pipe.transcribe(audioArray: segment)
                if let text = results.text {
                    DispatchQueue.main.async {
                        self.currentText += " " + text
                        self.partialText = "" // Clear partial
                    }
                }
            } catch {
                print("Finalize error: \(error)")
            }
            
            self.isInferencing = false
        }
    }
}
