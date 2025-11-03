# @dariyd/react-native-image-description

[![npm version](https://badge.fury.io/js/%40dariyd%2Freact-native-image-description.svg)](https://badge.fury.io/js/%40dariyd%2Freact-native-image-description)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

React Native module for image classification and description using native ML capabilities:
- **iOS**: Vision framework's `VNClassifyImageRequest` for image classification
- **Android**: ML Kit Image Labeling + GenAI Image Description API

## Features

✨ **Image Classification**
- Get labels with confidence scores for any image
- Configurable precision/recall thresholds (iOS)
- Filter by confidence threshold (Android)
- High-performance on-device processing

✨ **Image Description** (Android Only)
- Natural language descriptions of images
- On-device GenAI model
- Model download management with progress tracking

✨ **Modern Architecture**
- Full React Native new architecture support (iOS TurboModule)
- TypeScript with complete type definitions
- Promise-based async API
- Backward compatible with old architecture

## Installation

```bash
npm install @dariyd/react-native-image-description
# or
yarn add @dariyd/react-native-image-description
```

### iOS Setup

```bash
cd ios && pod install
```

**Requirements:**
- iOS 15.0 or higher
- Xcode 14 or higher

### Android Setup

The module will be automatically linked. No additional setup required.

**Requirements:**
- Android SDK 26 or higher
- Google Play Services

## Usage

### Basic Image Classification

```typescript
import { classifyImage } from '@dariyd/react-native-image-description';

// Classify an image
const result = await classifyImage('file:///path/to/image.jpg', {
  minimumConfidence: 0.5,
  maxResults: 10
});

if (result.success) {
  result.labels.forEach(label => {
    console.log(`${label.identifier}: ${(label.confidence * 100).toFixed(1)}%`);
  });
}

// Example output:
// dog: 95.2%
// animal: 92.8%
// pet: 89.3%
// mammal: 87.1%
```

### Image Description (Android Only)

```typescript
import {
  describeImage,
  checkDescriptionModelStatus,
  downloadDescriptionModel
} from '@dariyd/react-native-image-description';

// Check if model is available
const status = await checkDescriptionModelStatus();
console.log('Model status:', status); // 'available', 'downloadable', etc.

// Download model if needed
if (status === 'downloadable') {
  const success = await downloadDescriptionModel((progress) => {
    console.log(`Download progress: ${(progress * 100).toFixed(0)}%`);
  });
  
  if (success) {
    console.log('Model downloaded successfully!');
  }
}

// Generate description
const result = await describeImage('file:///path/to/image.jpg');

if (result.success) {
  console.log('Description:', result.description);
  // Example: "A golden retriever playing with a ball in a park"
}
```

### Check Module Availability

```typescript
import { isAvailable } from '@dariyd/react-native-image-description';

const available = await isAvailable();
if (available) {
  console.log('Image description module is ready!');
}
```

## API Reference

### `classifyImage(imageUri, options?)`

Classify an image and return labels with confidence scores.

**Parameters:**
- `imageUri` (string): Local file path or `file://` URI to the image
- `options` (object, optional):
  - `minimumPrecision` (number): 0.0-1.0, default 0.1 (iOS only)
  - `recallThreshold` (number): 0.0-1.0, default 0.8 (iOS only)
  - `minimumConfidence` (number): 0.0-1.0, filter results by confidence
  - `confidenceThreshold` (number): 0.0-1.0 (Android only, default 0.5)
  - `maxResults` (number): Limit number of results

**Returns:** `Promise<ClassificationResult>`
```typescript
{
  success: boolean;
  labels: Array<{
    identifier: string;
    confidence: number; // 0.0-1.0
    index?: number;
  }>;
  error?: string;
}
```

### `describeImage(imageUri, options?)` (Android Only)

Generate a natural language description of an image.

**Parameters:**
- `imageUri` (string): Local file path or `file://` URI to the image
- `options` (object, optional): Reserved for future use

**Returns:** `Promise<DescriptionResult>`
```typescript
{
  success: boolean;
  description: string;
  error?: string;
  modelStatus?: 'available' | 'downloading' | 'not_available';
}
```

**Note:** On iOS, this always returns an error indicating the feature is not available.

### `checkDescriptionModelStatus()` (Android Only)

Check the status of the GenAI description model.

**Returns:** `Promise<ModelStatus>`

Possible values:
- `'available'` - Model is downloaded and ready
- `'downloadable'` - Model needs to be downloaded
- `'downloading'` - Model is currently downloading
- `'not_available'` - Model cannot be used
- `'not_supported'` - Platform doesn't support this feature (iOS)

### `downloadDescriptionModel(onProgress?)` (Android Only)

Download the GenAI description model.

**Parameters:**
- `onProgress` (function, optional): Callback for download progress `(progress: number) => void`
  - `progress`: 0.0-1.0

**Returns:** `Promise<boolean>` - true if download succeeds

### `isAvailable()`

Check if the module is available on the current platform.

**Returns:** `Promise<boolean>` - true if available

## Platform Differences

### iOS (Vision Framework)

**Classification:**
- ✅ High-accuracy classification using Vision framework
- ✅ Taxonomy labels (e.g., "dog", "animal", "pet", "mammal")
- ✅ Configurable precision/recall thresholds
- ✅ Confidence scores for all labels
- ✅ iOS 15+ required

**Description:**
- ❌ Natural language description not available
- 💡 Use `classifyImage()` for classification labels instead
- 💡 For descriptions, consider cloud solutions (OpenAI Vision API, etc.)

### Android (ML Kit)

**Classification:**
- ✅ Fast on-device labeling with ML Kit
- ✅ 400+ entity categories
- ✅ Configurable confidence threshold
- ✅ No model download required

**Description:**
- ✅ Natural language descriptions via GenAI Image Description API
- ✅ On-device processing (privacy-friendly)
- ⚠️ Requires one-time model download (~50MB)
- ✅ Download progress tracking
- ⚠️ Beta API (subject to changes)

## Classification Options Explained

### iOS Precision/Recall Filtering

The Vision framework provides sophisticated filtering options:

**High-Recall Filter** (default):
```typescript
classifyImage(imageUri, {
  minimumPrecision: 0.1,
  recallThreshold: 0.8
});
```
- Returns more labels (broader range)
- May include some false positives
- Good for discovery and exploration

**High-Precision Filter**:
```typescript
classifyImage(imageUri, {
  minimumPrecision: 0.9,
  recallThreshold: 0.01
});
```
- Returns fewer labels (more conservative)
- Higher accuracy, fewer false positives
- Good for critical applications

### Android Confidence Threshold

```typescript
classifyImage(imageUri, {
  confidenceThreshold: 0.7  // Only labels with 70%+ confidence
});
```

## Example App

The `example/` directory contains a full React Native app demonstrating:
- Image picker integration
- Classification with confidence visualization
- Description generation (Android)
- Model download management
- Platform-specific UI

To run the example:

```bash
# Install dependencies
yarn bootstrap

# Run on iOS
cd example && yarn ios

# Run on Android
cd example && yarn android
```

## Performance Tips

1. **Image Size**: Resize large images before processing for faster results
2. **Model Download**: On Android, download the description model during app setup
3. **Caching**: Cache classification results for frequently used images
4. **Batch Processing**: Process multiple images sequentially, not concurrently

## Troubleshooting

### iOS Issues

**"iOS 15.0 or later is required"**
- Update your iOS deployment target to 15.0 in Xcode
- Update `platform :ios` in your Podfile

**Classification returns empty results**
- Check that the image file exists and is readable
- Verify the URI format (use `file://` prefix)
- Try lowering `minimumConfidence` threshold

### Android Issues

**"Model needs to be downloaded"**
- Call `downloadDescriptionModel()` before using `describeImage()`
- Ensure device has internet connection for initial download
- Check available storage space (~50MB required)

**Out of memory errors**
- Reduce image resolution before processing
- Process images one at a time
- Ensure proper cleanup (module handles this automatically)

**ML Kit not available**
- Verify Google Play Services is installed and up to date
- Check minimum SDK version is 26+
- Ensure app has internet permission in AndroidManifest.xml

## React Native New Architecture

This module fully supports the React Native new architecture:

### iOS
✅ **Native TurboModule implementation**
- Automatically detected when `RCT_NEW_ARCH_ENABLED=1`
- Seamless fallback to Bridge mode on old architecture
- Full CodeGen integration

### Android
✅ **Bridge mode with full compatibility**
- Works seamlessly with `newArchEnabled=true` (new arch apps)
- Works with `newArchEnabled=false` (old arch apps)
- Uses React Native's interop layer for maximum compatibility

## Comparison with Other Solutions

| Feature            | This Library         | react-native-mlkit | react-native-text-detector |
|--------------------|---------------------|-------------------|---------------------------|
| iOS Support        | ✅ Vision API        | ❌                 | ✅                         |
| Android Support    | ✅ ML Kit v2         | ✅ ML Kit          | ✅                         |
| Image Classification | ✅                 | ✅                 | ❌                         |
| Image Description  | ✅ Android           | ❌                 | ❌                         |
| New Architecture   | ✅ iOS TurboModule   | ❌                 | ❌                         |
| TypeScript         | ✅                   | ⚠️ Partial        | ❌                         |
| Active Maintenance | ✅                   | ⚠️                | ❌                         |

## Requirements

- React Native >= 0.77.3
- iOS 15.0+
- Android SDK 26+
- Xcode 14+ (for iOS development)
- Android Studio (for Android development)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Apache-2.0 © dariyd

## Acknowledgments

- iOS implementation uses Apple's Vision framework
- Android implementation uses Google ML Kit
- Inspired by [@dariyd/react-native-text-recognition](https://github.com/dariyd/react-native-text-recognition)

## Related Projects

- [@dariyd/react-native-text-recognition](https://github.com/dariyd/react-native-text-recognition) - Text recognition using Vision and ML Kit
- [react-native-vision-camera](https://github.com/mrousavy/react-native-vision-camera) - Camera library for React Native
- [react-native-image-picker](https://github.com/react-native-image-picker/react-native-image-picker) - Image picker for React Native

## Support

If you find this project useful, please consider:
- ⭐ Starring the repository
- 🐛 Reporting issues
- 📖 Improving documentation
- 🔧 Contributing code

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.

## Roadmap

- [ ] Custom Core ML model support (iOS)
- [ ] TensorFlow Lite model support (Android)
- [ ] Image similarity search
- [ ] Batch processing API
- [ ] Cloud-based description for iOS
- [ ] Video frame classification

