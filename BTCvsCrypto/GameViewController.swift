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
        let titleLabel = UILabel()
        titleLabel.text = "BTCvsALTS"
        titleLabel.font = .boldSystemFont(ofSize: 32)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        configure(selectButton,  title: "Select Song", bg: .systemBlue)
        configure(playPauseButton, title: "Play",        bg: .systemGreen)

        selectButton.addTarget(self, action: #selector(selectSongTapped), for: .touchUpInside)
        playPauseButton.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [selectButton, playPauseButton])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            selectButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func configure(_ btn: UIButton, title: String, bg: UIColor) {
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = bg.withAlphaComponent(0.9)
        btn.layer.cornerRadius = 12
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
    }

    // MARK: – SpriteKit -------------------------------------------------
    private func setupSpriteKitView() {
        skView = SKView()
        skView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skView)

        if let stack = view.subviews.first(where: { $0 is UIStackView }) {
            NSLayoutConstraint.activate([
                skView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
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
