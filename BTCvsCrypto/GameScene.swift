import SpriteKit

private struct PCat {
    static let cube:   UInt32 = 1 << 0
    static let bullet: UInt32 = 1 << 1
}

class GameScene: SKScene,
                 AudioManagerDelegate,
                 SpectrumNodeDelegate,
                 SKPhysicsContactDelegate {
    // MARK: – Game state
    private var score: Int = 0
    private var scoreLabel: SKLabelNode!

    private var spectrum: SpectrumNode!
    private var ship:     SKSpriteNode!
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

        /* Spaceship */
        ship = SKSpriteNode(color: .white, size: CGSize(width: 50, height: 20))
        ship.position = CGPoint(x: size.width * 0.5, y: 70)
        addChild(ship)

        AudioManager.shared.delegate = self
        // Score display
        score = 0
        scoreLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: 20, y: size.height - 20)
        scoreLabel.zPosition = 100
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
    }

    // MARK: – Audio
    func audioManager(_ m: AudioManager, didUpdateSpectrum s: [Float]) {
        spectrum.updateSpectrum(s)
    }

    // MARK: – Spawn cube at timed peak
    func spectrumNode(_ node: SpectrumNode,
                       didCapturePeakAt scenePoint: CGPoint,
                       forBar barIndex: Int) {
        // prevent multiple cubes on the same bar until this one starts falling
        guard !pendingBars.contains(barIndex) else { return }
        pendingBars.insert(barIndex)
        let cubeSize: CGFloat = 8   // small pixel‑style cube
        let cube = SKSpriteNode(color: .systemPink,
                                size: CGSize(width: cubeSize, height: cubeSize))
        cube.name = "cube"
        cube.position = scenePoint
        // initially static until delay expires
        let body = SKPhysicsBody(rectangleOf: cube.size)
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
        if let t = touches.first {
            let location = t.location(in: self)
            ship.position.x = location.x
            // auto-fire bullets in three directions when moving
            shoot(dx: -200)
            shoot(dx: 0)
            shoot(dx: 200)
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shoot()
    }

    /// Fires a bullet from the ship with given horizontal velocity.
    /// - Parameter dx: horizontal velocity component (default 0).
    private func shoot(dx: CGFloat = 0) {
        let bullet = SKSpriteNode(color: .yellow,
                                  size: CGSize(width: 4, height: 12))
        bullet.position = CGPoint(x: ship.position.x,
                                  y: ship.position.y + ship.size.height/2)

        let body = SKPhysicsBody(rectangleOf: bullet.size)
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

    // MARK: – Collisions
    func didBegin(_ contact: SKPhysicsContact) {
        // detect cube–bullet collision
        guard contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
              == (PCat.cube | PCat.bullet) else {
            return
        }
        // update score
        score += 1
        scoreLabel.text = "Score: \(score)"
        // remove both nodes
        contact.bodyA.node?.removeFromParent()
        contact.bodyB.node?.removeFromParent()
    }
}
