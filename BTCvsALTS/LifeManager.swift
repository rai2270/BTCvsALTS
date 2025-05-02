import SpriteKit

// A dedicated class to manage lives in the game to ensure proper tracking
class LifeManager {
    // The actual number of lives
    private(set) var lives: Int
    
    // The label that displays the lives
    private weak var livesLabel: SKLabelNode?
    
    // Flag to prevent multiple life losses in quick succession
    private var isInCooldown = false
    
    // Initialize with starting lives and the label to update
    init(startingLives: Int, label: SKLabelNode) {
        self.lives = startingLives
        self.livesLabel = label
        updateDisplay()
    }
    
    // Update the lives display
    private func updateDisplay() {
        livesLabel?.text = "Lives: \(lives)"
        print("Lives display updated: \(lives)")
    }
    
    // Lose a life - returns true if life was lost, false if in cooldown
    func loseLife() -> Bool {
        // Prevent multiple life losses in quick succession
        if isInCooldown {
            print("In cooldown - life not lost")
            return false
        }
        
        // Reduce lives by exactly 1
        lives = max(0, lives - 1)
        updateDisplay()
        
        // Set cooldown to prevent multiple losses
        isInCooldown = true
        
        // Create a timer to reset the cooldown
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isInCooldown = false
        }
        
        print("Life lost - Lives remaining: \(lives)")
        return true
    }
    
    // Reset lives to starting amount
    func reset(to amount: Int) {
        lives = amount
        isInCooldown = false
        updateDisplay()
        print("Lives reset to: \(lives)")
    }
    
    // Check if game is over (no lives left)
    var isGameOver: Bool {
        return lives <= 0
    }
}
