import SpriteKit

/// Communicates game state changes to its delegate
protocol GameSceneDelegate: AnyObject {
    func gameDidEnd(withScore score: Int)
    func gameDidRestart()
}

private struct PCat {
    static let cube:   UInt32 = 1 << 0
    static let bullet: UInt32 = 1 << 1
}

class GameScene: SKScene,
                 AudioManagerDelegate,
                 SpectrumNodeDelegate,
                 SKPhysicsContactDelegate {
    
    weak var gameDelegate: GameSceneDelegate?
    
    // Game states
    enum GameState {
        case playing
        case gameOver
        case victory
    }
    // MARK: – Game state
    private var score: Int = 0
    private var gameState: GameState = .playing
    private var scoreLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!
    
    // Use the dedicated LifeManager to handle lives
    private var lifeManager: LifeManager!
    private var gameOverNode: SKNode!
    private var victoryNode: SKNode!
    
    // Track last spawned altcoin type to ensure variety
    private var lastAltcoinType: Int = -1
    
    // Cooldown protection for losing lives
    private var lifeLossCooldown: TimeInterval = 0

    private var spectrum: SpectrumNode!
    private var ship:     SKNode! // Changed from SKSpriteNode to SKNode
    // Track which bars currently have a pending cube
    private var pendingBars = Set<Int>()

    // MARK: – Setup
    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self

        /* Spectrum upper third */
        let specSize = CGSize(width: size.width * 0.9,
                              height: size.height * 0.28)
        spectrum = SpectrumNode(size: specSize)
        spectrum.position = CGPoint(x: size.width * 0.5,
                                    y: size.height * 0.66)
        spectrum.delegate = self
        addChild(spectrum)

        /* Bitcoin spaceship */
        createBitcoinShip()

        AudioManager.shared.delegate = self
        // Score display with Bitcoin theme
        score = 0
        gameState = .playing
        // Note: lives are now managed by lifeManager
        
        // Score display
        scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 20, y: size.height - 20)
        scoreLabel.zPosition = 100
        scoreLabel.text = "BTC: 0"
        
        // Add background to make score more visible
        let scoreBg = SKShapeNode(rectOf: CGSize(width: 120, height: 36), cornerRadius: 8)
        scoreBg.fillColor = UIColor.black.withAlphaComponent(0.6)
        scoreBg.strokeColor = UIColor.white.withAlphaComponent(0.4)
        scoreBg.position = CGPoint(x: 70, y: size.height - 25)
        scoreBg.zPosition = 99
        addChild(scoreBg)
        addChild(scoreLabel)
        
        // Lives display
        livesLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        livesLabel.fontSize = 24
        livesLabel.fontColor = .red
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.verticalAlignmentMode = .top
        livesLabel.position = CGPoint(x: size.width - 20, y: size.height - 20)
        livesLabel.zPosition = 100
        livesLabel.text = "Lives: 30" // Initial text, will be updated by LifeManager
        
        // Add background for lives
        let livesBg = SKShapeNode(rectOf: CGSize(width: 120, height: 36), cornerRadius: 8)
        livesBg.fillColor = UIColor.black.withAlphaComponent(0.6)
        livesBg.strokeColor = UIColor.white.withAlphaComponent(0.4)
        livesBg.position = CGPoint(x: size.width - 70, y: size.height - 25)
        livesBg.zPosition = 99
        addChild(livesBg)
        addChild(livesLabel)
        
        // Initialize LifeManager with 30 lives
        lifeManager = LifeManager(startingLives: 30, label: livesLabel)
        
        // Prepare (but don't show) game over and victory nodes
        setupGameOverNode()
        setupVictoryScreen()
    }

    // MARK: – Audio
    // MARK: - AudioManagerDelegate methods
    
    func audioManager(_ m: AudioManager, didUpdateSpectrum s: [Float]) {
        spectrum.updateSpectrum(s)
    }
    
    func audioManagerDidFinishPlaying(_ manager: AudioManager) {
        // When music ends, if player still has lives, show victory screen
        if gameState == .playing && lifeManager.lives > 0 {
            showVictoryScreen()
        }
    }

    // MARK: – Spawn cube at timed peak
    func spectrumNode(_ node: SpectrumNode,
                       didCapturePeakAt scenePoint: CGPoint,
                       forBar barIndex: Int) {
        // prevent multiple cubes on the same bar until this one starts falling
        guard !pendingBars.contains(barIndex) else { return }
        
        // Limit initial wave of coins when a song starts
        if score < 5 && pendingBars.count > 2 {
            // Only spawn if we randomly decide to (30% chance when score is low)
            guard Int.random(in: 1...10) <= 3 else { return }
        }
        
        pendingBars.insert(barIndex)
        
        // Get a different altcoin type than the last one that spawned
        var coinIndex = Int.random(in: 0...4) // Random altcoin type
        while coinIndex == lastAltcoinType && lastAltcoinType != -1 {
            coinIndex = Int.random(in: 0...4) // Keep trying until we get a different type
        }
        lastAltcoinType = coinIndex // Remember this type
        
        let coinColor = getCryptoColor(forIndex: coinIndex)
        let coinSize: CGFloat = 20
        
        // Create base node for the altcoin
        let cube = SKShapeNode()
        cube.name = "cube"
        cube.position = scenePoint
        
        // Create a different shape for each type of altcoin
        switch coinIndex {
        case 0: // ETH (diamond)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: coinSize/2))
            path.addLine(to: CGPoint(x: coinSize/2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -coinSize/2))
            path.addLine(to: CGPoint(x: -coinSize/2, y: 0))
            path.close()
            cube.path = path.cgPath
            cube.fillColor = coinColor
            cube.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            cube.lineWidth = 1.5
            
            // Simple falling motion (no special pattern)
            
        case 1: // DOGE (circle with D)
            cube.path = CGPath(ellipseIn: CGRect(x: -coinSize/2, y: -coinSize/2, width: coinSize, height: coinSize), transform: nil)
            cube.fillColor = coinColor
            cube.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            cube.lineWidth = 1.5
            
            let label = SKLabelNode(text: "D")
            label.fontName = "Helvetica-Bold"
            label.fontSize = coinSize * 0.6
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            cube.addChild(label)
            
            // Simple falling motion (no special pattern)
            
        case 2: // LTC (silver hexagon)
            let path = UIBezierPath()
            for i in 0..<6 {
                let angle = CGFloat(i) * (CGFloat.pi / 3)
                let point = CGPoint(x: coinSize/2 * cos(angle), y: coinSize/2 * sin(angle))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.close()
            cube.path = path.cgPath
            cube.fillColor = coinColor
            cube.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            cube.lineWidth = 1.5
            
            // Simple falling motion (no special pattern)
            
        case 3: // XRP (3D triangle)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: coinSize/2))
            path.addLine(to: CGPoint(x: coinSize/2, y: -coinSize/4))
            path.addLine(to: CGPoint(x: -coinSize/2, y: -coinSize/4))
            path.close()
            cube.path = path.cgPath
            cube.fillColor = coinColor
            cube.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            cube.lineWidth = 1.5
            
            // Simple falling motion (no special pattern)
            
        default: // Generic coin (octagon)
            let path = UIBezierPath()
            for i in 0..<8 {
                let angle = CGFloat(i) * (CGFloat.pi / 4)
                let point = CGPoint(x: coinSize/2 * cos(angle), y: coinSize/2 * sin(angle))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.close()
            cube.path = path.cgPath
            cube.fillColor = coinColor
            cube.strokeColor = UIColor(white: 1.0, alpha: 0.8)
            cube.lineWidth = 1.5
            
            // Simple falling motion (no special pattern)
        }
        
        // Add pulsating effect
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 1.0, duration: 0.5)
        ])
        cube.run(SKAction.repeatForever(pulse))
        
        // initially static until delay expires
        let body = SKPhysicsBody(circleOfRadius: coinSize/2)
        body.isDynamic = false
        body.affectedByGravity = false
        body.categoryBitMask = PCat.cube
        body.contactTestBitMask = PCat.bullet
        body.collisionBitMask = 0
        cube.physicsBody = body
        addChild(cube)
        
        // wait, then enable gravity so it drops
        let delay = SKAction.wait(forDuration: 0.5)
        let activatePhysics = SKAction.run { [weak cube] in
            guard let cube = cube,
                  let body = cube.physicsBody else { return }
            body.isDynamic = true
            body.affectedByGravity = true
        }
        cube.run(.sequence([delay, activatePhysics]))
        // clear pending flag after same delay, even if cube is removed early
        let clearPending = SKAction.sequence([
            delay,
            SKAction.run { [weak self] in
                self?.pendingBars.remove(barIndex)
            }
        ])
        self.run(clearPending)
    }

    // MARK: – Controls
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            return // Don't process movement when game is over
        }
        
        if let t = touches.first {
            let location = t.location(in: self)
            ship.position.x = location.x
            
            // Don't let the ship move off-screen
            let halfWidth = 25.0
            if ship.position.x < halfWidth {
                ship.position.x = halfWidth
            } else if ship.position.x > size.width - halfWidth {
                ship.position.x = size.width - halfWidth
            }
            
            // auto-fire bullets in three directions when moving
            shoot(dx: -200)
            shoot(dx: 0)
            shoot(dx: 200)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)
        
        if gameState == .gameOver || gameState == .victory {
            // Check if restart button was tapped on either game over or victory screen
            let nodeToCheck = gameState == .gameOver ? gameOverNode : victoryNode
            
            if let restartButton = nodeToCheck?.childNode(withName: "restartButton") {
                if restartButton.contains(touchLocation) {
                    restartGame()
                }
            }
        } else {
            shoot()
        }
    }

    /// Fires a bullet from the ship with given horizontal velocity.
    /// - Parameter dx: horizontal velocity component (default 0).
    private func shoot(dx: CGFloat = 0) {
        if gameState == .gameOver || gameState == .victory {
            return // Don't shoot when game is over or won
        }
        // Create a Bitcoin-themed bullet (orange circle with B symbol)
        let bulletSize: CGFloat = 15
        
        // Create the main bullet node
        let bullet = SKShapeNode(circleOfRadius: bulletSize/2)
        bullet.fillColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        bullet.strokeColor = .white
        bullet.lineWidth = 1.0
        // Position the bullet right above the ship (we now use a fixed offset since SKNode doesn't have size)
        bullet.position = CGPoint(x: ship?.position.x ?? 0, y: ship?.position.y ?? 0 + 15)
        bullet.name = "bullet"
        
        // Add 'B' label on top
        let label = SKLabelNode(text: "B")
        label.fontName = "Helvetica-Bold"
        label.fontSize = bulletSize * 0.6
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        bullet.addChild(label)
        
        // Add glow effect
        let glowEffect = SKEffectNode()
        glowEffect.shouldRasterize = true
        glowEffect.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 2.0])
        let glowShape = SKShapeNode(circleOfRadius: bulletSize/2 + 1)
        glowShape.fillColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 0.3)
        glowShape.strokeColor = .clear
        glowEffect.addChild(glowShape)
        bullet.addChild(glowEffect)
        
        // Create physics body
        let body = SKPhysicsBody(circleOfRadius: bulletSize/2)
        body.isDynamic = true
        body.affectedByGravity = false
        body.velocity = CGVector(dx: dx, dy: 800)
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PCat.bullet
        body.contactTestBitMask = PCat.cube
        body.collisionBitMask = 0
        bullet.physicsBody = body
        addChild(bullet)

        let lifetime = (size.height - bullet.position.y) / 800 + 0.5
        bullet.run(.sequence([.wait(forDuration: TimeInterval(lifetime)),
                              .removeFromParent()]))
    }

    // MARK: – Helper methods
    
    // Speed control function - can be used later to adjust difficulty
    private func getCurrentFallSpeed() -> CGFloat {
        // Base speed with small increase as score rises
        let baseSpeed = 200.0
        let speedIncrease = min(CGFloat(score) / 50.0, 0.5) // Max 50% faster at high scores
        return baseSpeed * (1.0 + speedIncrease)
    }
    
    /// Sets up the game over screen
    private func setupGameOverNode() {
        gameOverNode = SKNode()
        gameOverNode?.alpha = 0
        gameOverNode?.zPosition = 1000
        gameOverNode?.isHidden = true
        addChild(gameOverNode ?? SKNode())
        
        // Semi-transparent background
        let background = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        background.fillColor = UIColor.black.withAlphaComponent(0.7)
        background.strokeColor = .clear
        background.position = CGPoint(x: size.width/2, y: size.height/2)
        gameOverNode?.addChild(background)
        
        // Game over text
        let gameOverText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        gameOverText.text = "GAME OVER"
        gameOverText.fontSize = 52
        gameOverText.fontColor = .red
        gameOverText.position = CGPoint(x: size.width/2, y: size.height/2 + 100)
        gameOverNode?.addChild(gameOverText)
        
        // Bitcoin crashed text
        let btcCrashedText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        btcCrashedText.text = "Bitcoin Crashed!"
        btcCrashedText.fontSize = 32
        btcCrashedText.fontColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        btcCrashedText.position = CGPoint(x: size.width/2, y: size.height/2 + 50)
        gameOverNode?.addChild(btcCrashedText)
        
        // Final score
        let finalScoreText = SKLabelNode(fontNamed: "HelveticaNeue")
        finalScoreText.name = "finalScore"
        finalScoreText.text = "Final BTC: 0"
        finalScoreText.fontSize = 30
        finalScoreText.fontColor = .white
        finalScoreText.position = CGPoint(x: size.width/2, y: size.height/2)
        gameOverNode?.addChild(finalScoreText)
        
        // Restart button
        let restartButton = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 10)
        restartButton.name = "restartButton"
        restartButton.fillColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        restartButton.strokeColor = .white
        restartButton.lineWidth = 2
        restartButton.position = CGPoint(x: size.width/2, y: size.height/2 - 80)
        gameOverNode?.addChild(restartButton)
        
        // Restart button text
        let restartText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        restartText.text = "RESTART"
        restartText.name = "restartButton" // Same name to capture touches
        restartText.fontSize = 28
        restartText.fontColor = .white
        restartText.verticalAlignmentMode = .center
        restartText.horizontalAlignmentMode = .center
        restartText.position = CGPoint(x: 0, y: 0)
        restartButton.addChild(restartText)
    }
    
    /// Sets up the victory screen
    private func setupVictoryScreen() {
        victoryNode = SKNode()
        victoryNode?.alpha = 0
        victoryNode?.zPosition = 1000
        victoryNode?.isHidden = true
        addChild(victoryNode ?? SKNode())
        
        // Semi-transparent background
        let background = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        background.fillColor = UIColor.black.withAlphaComponent(0.7)
        background.strokeColor = .clear
        background.position = CGPoint(x: size.width/2, y: size.height/2)
        victoryNode?.addChild(background)
        
        // Victory text
        let victoryText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        victoryText.text = "VICTORY"
        victoryText.fontSize = 52
        victoryText.fontColor = .green
        victoryText.position = CGPoint(x: size.width/2, y: size.height/2 + 100)
        victoryNode?.addChild(victoryText)
        
        // Bitcoin survived text
        let btcSurvivedText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        btcSurvivedText.text = "Bitcoin Survived The ALTS!"
        btcSurvivedText.fontSize = 32
        btcSurvivedText.fontColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        btcSurvivedText.position = CGPoint(x: size.width/2, y: size.height/2 + 50)
        victoryNode?.addChild(btcSurvivedText)
        
        // Final score
        let finalScoreText = SKLabelNode(fontNamed: "HelveticaNeue")
        finalScoreText.name = "finalScore"
        finalScoreText.text = "Final BTC Score: 0"
        finalScoreText.fontSize = 30
        finalScoreText.fontColor = .white
        finalScoreText.position = CGPoint(x: size.width/2, y: size.height/2)
        victoryNode?.addChild(finalScoreText)
        
        // Lives remaining
        let livesRemainingText = SKLabelNode(fontNamed: "HelveticaNeue")
        livesRemainingText.name = "livesRemaining"
        livesRemainingText.text = "Lives Remaining: 0"
        livesRemainingText.fontSize = 30
        livesRemainingText.fontColor = .white
        livesRemainingText.position = CGPoint(x: size.width/2, y: size.height/2 - 30)
        victoryNode?.addChild(livesRemainingText)
        
        // Restart button
        let restartButton = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 10)
        restartButton.name = "restartButton"
        restartButton.fillColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        restartButton.strokeColor = .white
        restartButton.lineWidth = 2
        restartButton.position = CGPoint(x: size.width/2, y: size.height/2 - 80)
        victoryNode?.addChild(restartButton)
        
        // Restart button text
        let restartText = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        restartText.text = "RESTART"
        restartText.name = "restartButton" // Same name to capture touches
        restartText.fontSize = 28
        restartText.fontColor = .white
        restartText.verticalAlignmentMode = .center
        restartText.horizontalAlignmentMode = .center
        restartText.position = CGPoint(x: 0, y: 0)
        restartButton.addChild(restartText)
    }
    
    /// Shows the game over screen
    private func showGameOver() {
        gameState = .gameOver
        
        // Update final score
        if let finalScore = gameOverNode.childNode(withName: "finalScore") as? SKLabelNode {
            finalScore.text = "Final BTC: \(score)"
        }
        
        // Hide victory screen if visible
        victoryNode.isHidden = true
        
        gameOverNode.isHidden = false
        
        // Fade in the game over screen
        let fadeIn = SKAction.fadeIn(withDuration: 0.5)
        gameOverNode.run(fadeIn)
        
        // Stop game movement
        self.isPaused = false // Ensure the scene is unpaused to show animations
        spectrum.isPaused = true
        AudioManager.shared.stop() // Stop the music
        
        // Notify delegate that game has ended
        gameDelegate?.gameDidEnd(withScore: score)
    }
    
    /// Shows the victory screen when player completes the song with lives remaining
    private func showVictoryScreen() {
        gameState = .victory
        
        // Update final score and lives remaining
        if let finalScoreLabel = victoryNode?.childNode(withName: "finalScore") as? SKLabelNode {
            finalScoreLabel.text = "Final BTC Score: \(score)"
        }
        
        if let livesRemainingLabel = victoryNode?.childNode(withName: "livesRemaining") as? SKLabelNode {
            livesRemainingLabel.text = "Lives Remaining: \(lifeManager.lives)"
        }
        
        // Hide game over screen if visible
        gameOverNode?.isHidden = true
        
        // Animate the victory screen
        victoryNode?.isHidden = false
        victoryNode?.alpha = 0
        victoryNode?.run(SKAction.fadeIn(withDuration: 0.5))
        
        // Notify delegate that game is over with victory
        gameDelegate?.gameDidEnd(withScore: score)
    }
    
    /// Restarts the game
    private func restartGame() {
        // Hide game over and victory screens
        gameOverNode?.isHidden = true
        gameOverNode?.alpha = 0
        victoryNode?.isHidden = true
        victoryNode?.alpha = 0
        
        // Reset game state
        score = 0      // Reset score to 0
        gameState = .playing
        scoreLabel.text = "BTC: 0"
        
        // Reset lives using the LifeManager
        lifeManager.reset(to: 30)
        
        print("Game restarted: Score = \(score), Lives = \(lifeManager.lives)")
        
        // Clear all crypto coins
        self.enumerateChildNodes(withName: "cube") { node, _ in
            node.removeFromParent()
        }
        
        // Clear all bullets
        self.enumerateChildNodes(withName: "bullet") { node, _ in
            node.removeFromParent()
        }
        
        // Reset ship position
        ship?.position.x = size.width * 0.5
        
        // Reset pending bars
        pendingBars.removeAll()
        
        // Reset spectrum
        spectrum.isPaused = false
        
        // Note: We don't auto-restart music here
        // The player will need to select a song again using the UI
        
        // Notify delegate that game has restarted
        gameDelegate?.gameDidRestart()
    }
    
    /// Check if a crypto coin has reached the bottom, lose a life if so (with cooldown protection)
    private func checkForMissedCoins() {
        self.enumerateChildNodes(withName: "cube") { node, stop in
            if node.position.y < 30 && node.physicsBody?.isDynamic == true {
                // Coin reached the bottom, lose a life using the LifeManager
                // This automatically has cooldown protection built in
                if self.lifeManager.loseLife() {
                    // Debug print to verify we're only losing lives, not score
                    print("Missed coin - Lives: \(self.lifeManager.lives), Score: \(self.score)")
                    
                    // Check for game over
                    if self.lifeManager.isGameOver {
                        self.showGameOver()
                    }
                    
                    // Stop processing after losing one life
                    stop.pointee = true
                }
                
                // Remove the coin that hit the bottom
                node.removeFromParent()
            }
        }
    }
    
    // REMOVED: Old loseLife function is no longer needed since we're using LifeManager
    
    override func update(_ currentTime: TimeInterval) {
        // Only process updates if the game is active
        guard gameState == .playing else { return }
        
        // Check for missed coins in every frame if the game is still playing
        checkForMissedCoins()
    }
    
    /// Creates a texture for the thruster particles
    private func createSparkTexture() -> SKTexture {
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return SKTexture(image: image)
    }
    
    /// Creates an explosion effect at the given position
    private func createExplosionEffect(at position: CGPoint) {
        let explosion = SKEmitterNode()
        explosion.position = position
        explosion.particleTexture = createSparkTexture()
        explosion.particleBirthRate = 500
        explosion.numParticlesToEmit = 50
        explosion.particleLifetime = 0.5
        explosion.particleLifetimeRange = 0.3
        explosion.particleSpeed = 60
        explosion.particleSpeedRange = 30
        explosion.emissionAngle = 0
        explosion.emissionAngleRange = 2 * .pi
        explosion.particleAlpha = 1.0
        explosion.particleAlphaRange = 0.0
        explosion.particleAlphaSpeed = -1.0
        explosion.particleScale = 0.3
        explosion.particleScaleRange = 0.2
        explosion.particleScaleSpeed = -0.3
        explosion.particleColor = .white
        explosion.particleColorBlendFactor = 1.0
        explosion.xAcceleration = 0
        explosion.yAcceleration = 0
        explosion.zPosition = 3
        addChild(explosion)
        
        // Remove after effect is complete
        let wait = SKAction.wait(forDuration: 1.0)
        let remove = SKAction.removeFromParent()
        explosion.run(SKAction.sequence([wait, remove]))
    }
    
    /// Returns a color for different cryptocurrency symbols
    private func getCryptoColor(forIndex index: Int) -> UIColor {
        switch index {
        case 0:
            return UIColor(red: 113/255, green: 171/255, blue: 221/255, alpha: 1.0) // Ethereum blue
        case 1:
            return UIColor(red: 225/255, green: 187/255, blue: 0/255, alpha: 1.0) // Dogecoin yellow
        case 2:
            return UIColor(red: 181/255, green: 181/255, blue: 181/255, alpha: 1.0) // Litecoin silver
        case 3:
            return UIColor(red: 35/255, green: 41/255, blue: 55/255, alpha: 1.0) // Ripple dark blue
        default:
            return UIColor(red: 150/255, green: 100/255, blue: 200/255, alpha: 1.0) // Generic purple
        }
    }
    
    /// Creates a Bitcoin-themed ship for the player
    private func createBitcoinShip() {
        // Create parent node for the ship
        let shipNode = SKNode()
        shipNode.position = CGPoint(x: size.width * 0.5, y: 70)
        addChild(shipNode)
        
        // Create ship base (orange trapezoid)
        let shipPath = UIBezierPath()
        shipPath.move(to: CGPoint(x: -25, y: -10))
        shipPath.addLine(to: CGPoint(x: 25, y: -10))
        shipPath.addLine(to: CGPoint(x: 15, y: 10))
        shipPath.addLine(to: CGPoint(x: -15, y: 10))
        shipPath.close()
        
        let shipBase = SKShapeNode(path: shipPath.cgPath)
        shipBase.fillColor = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1.0) // Bitcoin orange
        shipBase.strokeColor = .white
        shipBase.lineWidth = 1.5
        shipBase.zPosition = 1
        shipNode.addChild(shipBase)
        
        // Add Bitcoin logo on top
        let logo = SKLabelNode(text: "₿")
        logo.fontName = "Helvetica-Bold"
        logo.fontSize = 20
        logo.fontColor = .white
        logo.verticalAlignmentMode = .center
        logo.horizontalAlignmentMode = .center
        logo.position = CGPoint(x: 0, y: 0)
        logo.zPosition = 2
        shipNode.addChild(logo)
        
        // Add engine thrusters (two blue rectangles)
        for xPos in [-15, 15] {
            let thruster = SKShapeNode(rectOf: CGSize(width: 6, height: 8))
            thruster.fillColor = UIColor(red: 64/255, green: 196/255, blue: 255/255, alpha: 1.0)
            thruster.strokeColor = .white
            thruster.lineWidth = 1
            thruster.position = CGPoint(x: CGFloat(xPos), y: -14)
            thruster.zPosition = 0
            shipNode.addChild(thruster)
            
            // Add thruster animation
            let thrusterFlame = SKEmitterNode()
            // Use a simple circle for the particle since we may not have a spark texture
            let sparkTexture = createSparkTexture()
            thrusterFlame.particleTexture = sparkTexture
            thrusterFlame.particleBirthRate = 50
            thrusterFlame.particleLifetime = 0.5
            thrusterFlame.particleSpeed = 30
            thrusterFlame.particleSpeedRange = 10
            thrusterFlame.particleAlpha = 0.7
            thrusterFlame.particleAlphaRange = 0.3
            thrusterFlame.particleAlphaSpeed = -1.0
            thrusterFlame.particleScale = 0.2
            thrusterFlame.particleScaleRange = 0.1
            thrusterFlame.particleScaleSpeed = -0.1
            thrusterFlame.particleColor = .cyan
            thrusterFlame.particleColorBlendFactor = 0.7
            thrusterFlame.particleRotation = 0
            thrusterFlame.particleRotationRange = 2 * .pi
            thrusterFlame.particlePosition = CGPoint(x: 0, y: -5)
            thrusterFlame.emissionAngle = .pi / 2 * 3 // Down
            thrusterFlame.emissionAngleRange = .pi / 4
            thrusterFlame.zPosition = -1
            thruster.addChild(thrusterFlame)
        }
        
        // Store ship reference
        self.ship = shipNode
    }
    
    // MARK: – Collisions
    func didBegin(_ contact: SKPhysicsContact) {
        // detect cube–bullet collision
        guard contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
              == (PCat.cube | PCat.bullet) else {
            return
        }
        
        // Get the positions for the explosion effect
        let contactPoint = contact.bodyA.node?.position ?? contact.bodyB.node?.position ?? .zero
        
        // Create explosion effect
        createExplosionEffect(at: contactPoint)
        
        // FIXED: Clearly separate score increment logic to avoid confusion with lives
        let oldScore = score
        score += 1  // Always increment score by 1 when hitting an altcoin
        scoreLabel.text = "BTC: \(score)"
        print("Score increased: \(oldScore) -> \(score)")
        
        // remove both nodes
        contact.bodyA.node?.removeFromParent()
        contact.bodyB.node?.removeFromParent()
    }
}
