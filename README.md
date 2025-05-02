# BTCvsCrypto

An iOS game where Bitcoin battles against altcoins in a music-driven arcade experience. The game uses real-time audio spectrum analysis to spawn crypto coins that fall from the top of the screen while you control a Bitcoin spaceship to shoot them down.

## Features

- Bitcoin-themed spaceship that fires Bitcoin projectiles
- Different altcoins represented as distinct shapes and colors (Ethereum, Dogecoin, Litecoin, XRP, and more)
- Music-driven gameplay where altcoins spawn based on audio frequency peaks
- Explosion effects when Bitcoin hits altcoins
- Real-time audio spectrum visualization using professional Mel-scale frequency mapping
- Select from bundled crypto-themed MP3 files or import your own via file picker
- Dynamic particle effects and smooth animations

## Installation

1. Clone this repository
2. Run `pod install` in the project directory
3. Open `BTCvsCrypto.xcworkspace` in Xcode
4. Build and run on a device or simulator

## How to Play

1. Tap "Select Song" to choose from bundled crypto-themed music or import your own
2. Control your Bitcoin spaceship by dragging left and right at the bottom of the screen
3. The spaceship automatically fires Bitcoin projectiles when you move it
4. Hit the falling altcoins to earn BTC points
5. Watch as the audio spectrum visualization creates waves of altcoins based on the music
6. Try to achieve the highest BTC score!

## Technical Details

- Uses Accelerate framework for real-time FFT analysis
- Implements Mel-scale frequency mapping for perceptually accurate visualization
- SpriteKit for efficient rendering of visualization elements
- AVAudioEngine for audio processing
