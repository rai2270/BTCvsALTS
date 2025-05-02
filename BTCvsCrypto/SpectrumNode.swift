import SpriteKit
import Accelerate

// Delegate sends a peak location once per analysis window
protocol SpectrumNodeDelegate: AnyObject {
    /// Called when a frequency band captures a timed peak.
    /// - Parameters:
    ///   - node: the SpectrumNode sending the event
    ///   - scenePoint: the location in scene coordinates where the peak occurred
    ///   - barIndex: index of the bar that produced this peak
    func spectrumNode(_ node: SpectrumNode,
                       didCapturePeakAt scenePoint: CGPoint,
                       forBar barIndex: Int)
}

/// Rainbow log‑frequency spectrum with timed peak capture.
class SpectrumNode: SKNode {

    // MARK: – Tunables
    private let barCount = 30
    private let dBWindow: Float = 50
    private let fallSpeed: CGFloat = 180
    private let gamma: Float = 0.7
    private let hfBoost: Float = 1.6
    private let minPeakFrac: CGFloat = 0.05          // ignore very small peaks
    private let windowDuration: TimeInterval = 0.65  // ← slowed from 0.20 s

    weak var delegate: SpectrumNodeDelegate?

    // MARK: – State
    private let nodeSize: CGSize
    private var bars: [SKSpriteNode] = []
    private var heights: [CGFloat]
    private var windowPeaks: [CGFloat]
    private var windowElapsed: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0

    // MARK: – Init
    init(size: CGSize) {
        nodeSize = size
        heights = Array(repeating: 0, count: barCount)
        windowPeaks = heights
        super.init()
        buildBars()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: – Build bars
    private func buildBars() {
        let gap: CGFloat = 0.1
        let totalGap = nodeSize.width * gap
        let barW = (nodeSize.width - totalGap) / CGFloat(barCount)
        let spacing = totalGap / CGFloat(barCount - 1)

        for i in 0..<barCount {
            let hue = CGFloat(i) / CGFloat(barCount)
            let bar = SKSpriteNode(color: SKColor(hue: hue,
                                                  saturation: 0.9,
                                                  brightness: 0.4,
                                                  alpha: 1),
                                   size: CGSize(width: barW, height: 1))
            bar.anchorPoint = CGPoint(x: 0.5, y: 0)
            let x = (-nodeSize.width/2) + CGFloat(i)*(barW+spacing) + barW/2
            bar.position = CGPoint(x: x, y: -nodeSize.height/2)
            addChild(bar)
            bars.append(bar)
        }
    }

    // MARK: – Frame update
    func updateSpectrum(_ spectrum: [Float]) {
        guard !spectrum.isEmpty else { return }

        // Δt
        let now = CACurrentMediaTime()
        let dt = (lastFrameTime == 0) ? 0 : now - lastFrameTime
        lastFrameTime = now
        windowElapsed += dt
        let decay = CGFloat(fallSpeed) * CGFloat(dt)

        // linear → dB
        var magsDB = spectrum
        var one: Float = 1
        vDSP_vdbcon(spectrum, 1, &one, &magsDB, 1,
                    vDSP_Length(spectrum.count), 0)
        let peakDB  = magsDB.max() ?? 0
        let floorDB = peakDB - dBWindow

        for i in 0..<barCount {
            // log‑spacing
            let norm = Float(i) / Float(barCount - 1)
            let binF = pow(norm, 2) * Float(spectrum.count - 1)
            let bin  = Int(binF)

            // small average
            let lo = max(0, bin-1), hi = min(spectrum.count-1, bin+1)
            var db = magsDB[lo...hi].reduce(0, +) / Float(hi-lo+1)
            db = max(floorDB, min(db, peakDB))

            var level = (db - floorDB) / dBWindow
            level *= 1 + (hfBoost - 1) * norm * norm
            level = pow(level, gamma)

            // rise / fall
            let target = CGFloat(level) * nodeSize.height
            heights[i] = max(heights[i], target)
            heights[i] = max(0, heights[i] - decay)

            // draw & colour
            bars[i].size.height = heights[i]
            let bright = 0.4 + 0.6 * (heights[i] / nodeSize.height)
            bars[i].color = bars[i].color.withBrightnessComponent(bright)

            // remember peak in this slice
            windowPeaks[i] = max(windowPeaks[i], heights[i])
        }

        // emit peaks every windowDuration
        if windowElapsed >= windowDuration, let scene = self.scene {
            for (i, peakHeight) in windowPeaks.enumerated()
            where peakHeight >= nodeSize.height * minPeakFrac {
                let bar = bars[i]
                let yPos = bar.position.y + peakHeight
                let localPoint = CGPoint(x: bar.position.x, y: yPos)
                let scenePoint = convert(localPoint, to: scene)
                delegate?.spectrumNode(self,
                                       didCapturePeakAt: scenePoint,
                                       forBar: i)
            }
            windowPeaks = Array(repeating: 0, count: barCount)
            windowElapsed = 0
        }
    }
}

// helper
private extension SKColor {
    func withBrightnessComponent(_ b: CGFloat) -> SKColor {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        return SKColor(hue: h, saturation: s, brightness: b, alpha: a)
    }
}
