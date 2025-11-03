# Quick Start Guide

Get up and running with `@dariyd/react-native-image-description` in minutes.

## Installation

```bash
npm install @dariyd/react-native-image-description
# or
yarn add @dariyd/react-native-image-description
```

### iOS

```bash
cd ios && pod install
```

### Android

No additional setup required. The module will be linked automatically.

## Basic Usage

### 1. Import the module

```typescript
import {
  classifyImage,
  describeImage,
  checkDescriptionModelStatus,
  downloadDescriptionModel,
} from '@dariyd/react-native-image-description';
```

### 2. Classify an image (iOS & Android)

```typescript
const result = await classifyImage('file:///path/to/image.jpg', {
  minimumConfidence: 0.5,
  maxResults: 10,
});

if (result.success) {
  result.labels.forEach(label => {
    console.log(`${label.identifier}: ${(label.confidence * 100).toFixed(1)}%`);
  });
}
```

### 3. Describe an image (Android only)

```typescript
// Check model status
const status = await checkDescriptionModelStatus();

// Download model if needed
if (status === 'downloadable') {
  await downloadDescriptionModel((progress) => {
    console.log(`Downloading: ${(progress * 100).toFixed(0)}%`);
  });
}

// Generate description
const result = await describeImage('file:///path/to/image.jpg');

if (result.success) {
  console.log('Description:', result.description);
}
```

## Complete Example

```typescript
import React, { useState } from 'react';
import { View, Button, Text, Image } from 'react-native';
import {
  classifyImage,
  ClassificationResult,
} from '@dariyd/react-native-image-description';
import { launchImageLibrary } from 'react-native-image-picker';

export default function App() {
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [result, setResult] = useState<ClassificationResult | null>(null);

  const pickAndClassify = async () => {
    const response = await launchImageLibrary({ mediaType: 'photo' });
    
    if (response.assets?.[0]?.uri) {
      const uri = response.assets[0].uri;
      setImageUri(uri);
      
      const classification = await classifyImage(uri, {
        minimumConfidence: 0.5,
        maxResults: 5,
      });
      
      setResult(classification);
    }
  };

  return (
    <View style={{ padding: 20 }}>
      <Button title="Pick & Classify Image" onPress={pickAndClassify} />
      
      {imageUri && (
        <Image 
          source={{ uri: imageUri }} 
          style={{ width: 300, height: 300, marginTop: 20 }}
        />
      )}
      
      {result?.success && (
        <View style={{ marginTop: 20 }}>
          <Text style={{ fontSize: 18, fontWeight: 'bold' }}>Results:</Text>
          {result.labels.map((label, index) => (
            <Text key={index}>
              {label.identifier}: {(label.confidence * 100).toFixed(1)}%
            </Text>
          ))}
        </View>
      )}
    </View>
  );
}
```

## Next Steps

- Read the full [README.md](README.md) for detailed API documentation
- Check out the [example app](example/) for a complete implementation
- Review [platform differences](README.md#platform-differences) between iOS and Android
- Explore [advanced options](README.md#api-reference) for fine-tuning

## Common Issues

### iOS: "Module not found"
```bash
cd ios && pod install && cd ..
npx react-native run-ios
```

### Android: "Model not available"
```typescript
// Download the model first
await downloadDescriptionModel();
```

### Image picker not working
```bash
npm install react-native-image-picker
# Follow setup instructions at:
# https://github.com/react-native-image-picker/react-native-image-picker
```

## Support

- 📚 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/dariyd/react-native-image-description/issues)
- 💬 [Discussions](https://github.com/dariyd/react-native-image-description/discussions)

