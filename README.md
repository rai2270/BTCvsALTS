# BTCvsCrypto

An iOS SpriteKit app that plays MP3 files and visualizes their audio spectrum in real-time using a perceptually accurate Mel-scale frequency mapping.

## Features

- Real-time audio spectrum visualization using professional Mel-scale frequency mapping
- Multiple visualization modes with colorful bar display
- Select from bundled MP3 files or import your own via file picker
- Play/pause functionality with visual feedback
- Smooth animations with reflections and glow effects

## Installation

1. Clone this repository
2. Run `pod install` in the project directory
3. Open `BTCvsCrypto.xcworkspace` in Xcode
4. Build and run on a device or simulator

## Usage

When the app launches:
1. Tap "Play" to choose from bundled songs or import your own
2. The spectrum visualization will respond to the audio in real-time
3. Use the "Select Song" button any time to choose a different audio file

## Technical Details

- Uses Accelerate framework for real-time FFT analysis
- Implements Mel-scale frequency mapping for perceptually accurate visualization
- SpriteKit for efficient rendering of visualization elements
- AVAudioEngine for audio processing
