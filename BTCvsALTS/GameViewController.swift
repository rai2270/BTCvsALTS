import UIKit
import SpriteKit
import UniformTypeIdentifiers

// Bundled MP3s (omit “.mp3” extension)
private let bundledSongs = ["Sunset", "FeelsGood2B", "btcVibing"]

class GameViewController: UIViewController,
                          UIDocumentPickerDelegate,
                          GameSceneDelegate {

    private let selectButton   = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private var skView: SKView!
    private var scenePresented = false        // ensure we present only once
    
    private var selectedURL: URL?

    // MARK: – View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupTopControls()
        setupSpriteKitView()
    }
    
    /// Present the SpriteKit scene **after** Auto‑Layout sets frames
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !scenePresented {
            presentScene()
            scenePresented = true
        }
    }

    // MARK: – UI layout -------------------------------------------------
    private func setupTopControls() {
        // Create a more compact header bar
        let headerBar = UIView()
        headerBar.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerBar)
        
        // Create a smaller title label with the Bitcoin orange color
        let titleLabel = UILabel()
        titleLabel.text = "BTCvsALTS"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(titleLabel)

        // Configure smaller, more compact buttons
        configure(selectButton, title: "Select", bg: .systemBlue)
        configure(playPauseButton, title: "Play", bg: .systemGreen)

        selectButton.addTarget(self, action: #selector(selectSongTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        // Create horizontal stack for buttons with less spacing
        let stack = UIStackView(arrangedSubviews: [selectButton, playPauseButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(stack)

        NSLayoutConstraint.activate([
            // Make header bar compact
            headerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 44), // Compact height
            
            // Position title on the left side
            titleLabel.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            
            // Position buttons on the right side
            stack.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            selectButton.heightAnchor.constraint(equalToConstant: 32) // Smaller buttons
        ])
    }

    private func configure(_ btn: UIButton, title: String, bg: UIColor) {
        // Create more compact buttons with smaller text
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = bg.withAlphaComponent(0.85)
        btn.layer.cornerRadius = 8 // Smaller corner radius
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold) // Smaller font
        
        // Add shadow for better visibility
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.3
        btn.layer.shadowRadius = 2
        
        // Add padding using content insets
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    }

    // MARK: – SpriteKit -------------------------------------------------
    private func setupSpriteKitView() {
        skView = SKView()
        skView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skView)

        // Find our header bar and position the game view directly beneath it
        if let headerBar = view.subviews.first(where: { $0.backgroundColor != nil }) {
            NSLayoutConstraint.activate([
                skView.topAnchor.constraint(equalTo: headerBar.bottomAnchor), // No gap
                skView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                skView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                skView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    private func presentScene() {
        // Force layout so skView has its final frame
        view.layoutIfNeeded()
        let sceneSize = skView.bounds.size
        let scene = GameScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        scene.gameDelegate = self
        skView.presentScene(scene)
    }

    // MARK: – Button actions -------------------------------------------
    @objc private func selectSongTapped() {
        let alert = UIAlertController(title: "Choose a Song", message: nil, preferredStyle: .actionSheet)

        for name in bundledSongs {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
                    self.play(url: url)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Browse Files…", style: .default) { _ in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
            picker.delegate = self
            self.present(picker, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = alert.popoverPresentationController {
            pop.sourceView = selectButton
            pop.sourceRect = selectButton.bounds
        }
        present(alert, animated: true)
    }

    @objc private func playPauseTapped() {
        if AudioManager.shared.isPlaying {
            AudioManager.shared.stop()
            playPauseButton.setTitle("Play", for: .normal)
            playPauseButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        } else {
            guard let url = selectedURL else {
                selectSongTapped()
                return
            }
            play(url: url)
        }
    }

    // MARK: – UIDocumentPicker -----------------------------------------
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        play(url: url)
    }

    // MARK: – Helper
    private func play(url: URL) {
        selectedURL = url
        do {
            try AudioManager.shared.play(url: url)
            playPauseButton.setTitle("Pause", for: .normal)
            playPauseButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        } catch {
            print("Audio play error:", error)
        }
    }
    
    // MARK: - GameSceneDelegate
    
    func gameDidEnd(withScore score: Int) {
        // Disable buttons when game ends
        selectButton.isEnabled = false
        playPauseButton.isEnabled = false
        
        // Dim buttons to indicate they're disabled
        selectButton.alpha = 0.5
        playPauseButton.alpha = 0.5
    }
    
    func gameDidRestart() {
        // Re-enable buttons when game restarts
        selectButton.isEnabled = true
        playPauseButton.isEnabled = true
        
        // Restore button appearance
        selectButton.alpha = 1.0
        playPauseButton.alpha = 1.0
        
        // Reset play/pause button to show "Play"
        playPauseButton.setTitle("Play", for: .normal)
        playPauseButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        
        // User has to select song again
        selectedURL = nil
    }
}
