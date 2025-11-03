# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-02

### Added

#### iOS
- Image classification using Vision framework's `VNClassifyImageRequest`
- Support for iOS 15.0+
- High-recall and high-precision filtering options
- TurboModule implementation for new architecture
- Automatic fallback to Bridge mode for old architecture
- Confidence score filtering
- Max results limiting

#### Android
- Image classification using ML Kit Image Labeling API
- Image description using ML Kit GenAI Image Description API
- On-device model management
- Model download with progress tracking
- Configurable confidence thresholds
- Support for Android SDK 26+

#### TypeScript
- Complete TypeScript definitions
- Type-safe API with proper interfaces
- CodeGen specs for new architecture
- Promise-based async API

#### Example App
- Image picker integration
- Classification results with confidence visualization
- Description generation UI (Android)
- Model download progress tracking
- Platform-specific feature handling

#### Documentation
- Comprehensive README with usage examples
- API reference documentation
- Platform differences explained
- Troubleshooting guide
- Performance tips

### Technical Details
- React Native 0.77.3+ support
- Full new architecture compatibility
- Bridge mode with interop layer (Android)
- Native TurboModule (iOS)
- Proper resource cleanup
- Event emitters for progress tracking

[1.0.0]: https://github.com/dariyd/react-native-image-description/releases/tag/v1.0.0

