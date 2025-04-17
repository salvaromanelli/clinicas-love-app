# AR Face Treatment Simulator

This project is an AR application that utilizes ARKit and ARFaceTrackingConfiguration to detect facial points in real-time. The detected facial features can be sent to the Replicate API for modifying specific facial features in an aesthetic treatment simulator.

## Features

- Real-time facial tracking using ARKit.
- Detection of specific facial points for aesthetic treatments.
- Integration with the Replicate API to modify facial features.
- Custom overlay view to visualize detected facial features.

## Setup Instructions

1. **Clone the Repository**
   ```
   git clone <repository-url>
   cd ar-face-treatment-simulator
   ```

2. **Install CocoaPods**
   Make sure you have CocoaPods installed. If not, install it using:
   ```
   sudo gem install cocoapods
   ```

3. **Install Dependencies**
   Navigate to the project directory and run:
   ```
   pod install
   ```

4. **Open the Project**
   Open the `.xcworkspace` file in Xcode:
   ```
   open ARFaceTreatmentSimulator.xcworkspace
   ```

5. **Run the Application**
   Select a simulator or a physical device and run the application.

## Usage

- Grant camera access when prompted.
- The app will start detecting facial features in real-time.
- Detected points will be visualized on the screen.
- The application can send the detected facial data to the Replicate API for modifications.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.