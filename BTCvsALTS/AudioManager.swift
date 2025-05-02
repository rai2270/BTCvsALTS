import Foundation
import AVFoundation
import Accelerate

/// Sends real‑time FFT magnitudes to its delegate.
protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didUpdateSpectrum spectrum: [Float])
}

final class AudioManager {
    
    static let shared = AudioManager()
    
    weak var delegate: AudioManagerDelegate?
    
    private let engine     = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    private let fftSize    = 1024
    private let log2n: vDSP_Length
    private let window: [Float]
    private let fftSetup: FFTSetup
    
    private init() {
        log2n   = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))!
        var win  = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&win, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        window = win
    }
    
    // MARK: – Playback helpers recognised by GameViewController
    
    private(set) var isPlaying = false
    
    /// Keeps old API used by GameViewController.
    func start(url: URL) {
        try? play(url: url)
    }
    
    /// Modern name.
    func play(url: URL) throws {
        try configureEngineIfNeeded()
        
        let file = try AVAudioFile(forReading: url)
        playerNode.stop()
        playerNode.scheduleFile(file, at: nil, completionHandler: nil)
        playerNode.play()
        isPlaying = true
    }
    
    func stop() {
        playerNode.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        isPlaying = false
    }
    
    // MARK: – Engine / tap
    
    private func configureEngineIfNeeded() throws {
        guard engine.isRunning == false else { return }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        engine.mainMixerNode.installTap(onBus: 0,
                                        bufferSize: AVAudioFrameCount(fftSize),
                                        format: engine.mainMixerNode.outputFormat(forBus: 0))
        { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        
        try engine.start()
    }
    
    // MARK: – FFT
    
    private func process(buffer: AVAudioPCMBuffer) {
        guard let samples = buffer.floatChannelData?[0] else { return }
        
        // Copy first fftSize samples & apply Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
        
        // Convert to split‑complex
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        real.withUnsafeMutableBufferPointer { rPtr in
            imag.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPSplitComplex(realp: rPtr.baseAddress!,
                                            imagp: iPtr.baseAddress!)
                
                windowed.withUnsafeBufferPointer { srcPtr in
                    srcPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                          capacity: fftSize) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(fftSize/2))
                    }
                }
                
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                
                var mags = [Float](repeating: 0, count: fftSize/2)
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(fftSize/2))
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.audioManager(self, didUpdateSpectrum: mags)
                }
            }
        }
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
}
