import { NativeModules, Platform, NativeEventEmitter } from 'react-native';
import type {
  ClassificationResult,
  ClassificationOptions,
  DescriptionResult,
  DescriptionOptions,
  ModelStatus,
  ModelDownloadProgress,
} from './types';

const LINKING_ERROR =
  `The package '@dariyd/react-native-image-description' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

// Try to get the native module
let NativeImageDescription: any;

try {
  // For new architecture
  NativeImageDescription =
    require('./NativeImageDescription').default;
} catch (e) {
  // Fallback to old architecture
  NativeImageDescription = NativeModules.ImageDescription;
}

if (!NativeImageDescription) {
  throw new Error(LINKING_ERROR);
}

// Create event emitter for download progress
const eventEmitter = new NativeEventEmitter(NativeImageDescription);

/**
 * Classify an image and return labels with confidence scores.
 * 
 * iOS: Uses Vision framework's VNClassifyImageRequest
 * Android: Uses ML Kit Image Labeling API
 * 
 * @param imageUri - Local file path or file:// URI to the image
 * @param options - Classification options
 * @returns Promise with classification results
 * 
 * @example
 * ```typescript
 * const result = await classifyImage('file:///path/to/image.jpg', {
 *   minimumConfidence: 0.5,
 *   maxResults: 10
 * });
 * 
 * if (result.success) {
 *   result.labels.forEach(label => {
 *     console.log(`${label.identifier}: ${label.confidence}`);
 *   });
 * }
 * ```
 */
export async function classifyImage(
  imageUri: string,
  options?: ClassificationOptions
): Promise<ClassificationResult> {
  try {
    const result = await NativeImageDescription.classifyImage(
      imageUri,
      options || {}
    );
    return result as ClassificationResult;
  } catch (error) {
    return {
      success: false,
      labels: [],
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/**
 * Generate a natural language description of an image.
 * 
 * iOS: Not supported (returns error - use classifyImage for taxonomy labels)
 * Android: Uses ML Kit GenAI Image Description API (requires model download)
 * 
 * @param imageUri - Local file path or file:// URI to the image
 * @param options - Description options
 * @returns Promise with description result
 * 
 * @example
 * ```typescript
 * // Check model status first (Android)
 * const status = await checkDescriptionModelStatus();
 * if (status === 'downloadable') {
 *   await downloadDescriptionModel((progress) => {
 *     console.log(`Download progress: ${progress * 100}%`);
 *   });
 * }
 * 
 * const result = await describeImage('file:///path/to/image.jpg');
 * if (result.success) {
 *   console.log('Description:', result.description);
 * }
 * ```
 */
export async function describeImage(
  imageUri: string,
  options?: DescriptionOptions
): Promise<DescriptionResult> {
  try {
    if (Platform.OS === 'ios') {
      return {
        success: false,
        description: '',
        error:
          'Image description is not available on iOS. Use classifyImage() for classification labels.',
        modelStatus: 'not_supported',
      };
    }

    const result = await NativeImageDescription.describeImage(
      imageUri,
      options || {}
    );
    return result as DescriptionResult;
  } catch (error) {
    return {
      success: false,
      description: '',
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/**
 * Check the status of the GenAI description model (Android only).
 * 
 * @returns Promise with model status
 * 
 * Possible statuses:
 * - 'available': Model is downloaded and ready
 * - 'downloadable': Model needs to be downloaded
 * - 'downloading': Model is currently downloading
 * - 'not_available': Model cannot be used
 * - 'not_supported': Platform doesn't support this feature (iOS)
 */
export async function checkDescriptionModelStatus(): Promise<ModelStatus> {
  try {
    if (Platform.OS === 'ios') {
      return 'not_supported';
    }

    const status = await NativeImageDescription.checkDescriptionModelStatus();
    return status as ModelStatus;
  } catch (error) {
    console.error('Error checking model status:', error);
    return 'not_available';
  }
}

/**
 * Download the GenAI description model (Android only).
 * 
 * @param onProgress - Optional callback for download progress updates
 * @returns Promise that resolves to true if download succeeds
 * 
 * @example
 * ```typescript
 * const success = await downloadDescriptionModel((progress) => {
 *   console.log(`Downloading: ${Math.round(progress * 100)}%`);
 * });
 * ```
 */
export async function downloadDescriptionModel(
  onProgress?: (progress: number) => void
): Promise<boolean> {
  try {
    if (Platform.OS === 'ios') {
      console.warn('Model download is not supported on iOS');
      return false;
    }

    // Subscribe to progress events
    let subscription: any;
    if (onProgress) {
      subscription = eventEmitter.addListener(
        'ImageDescriptionModelDownloadProgress',
        (event: ModelDownloadProgress) => {
          onProgress(event.progress);
        }
      );
    }

    try {
      const result = await NativeImageDescription.downloadDescriptionModel();
      return result;
    } finally {
      if (subscription) {
        subscription.remove();
      }
    }
  } catch (error) {
    console.error('Error downloading model:', error);
    return false;
  }
}

/**
 * Check if the module is available on the current platform.
 * 
 * @returns Promise that resolves to true if the module is available
 */
export async function isAvailable(): Promise<boolean> {
  try {
    return await NativeImageDescription.isAvailable();
  } catch (error) {
    return false;
  }
}

// Export types
export type {
  ClassificationResult,
  ClassificationLabel,
  ClassificationOptions,
  DescriptionResult,
  DescriptionOptions,
  ModelStatus,
  ModelDownloadProgress,
} from './types';

