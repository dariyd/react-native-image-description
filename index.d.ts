// Type definitions for @dariyd/react-native-image-description
// Project: https://github.com/dariyd/react-native-image-description
// Definitions by: dariyd

export interface ClassificationLabel {
  identifier: string;
  confidence: number;
  index?: number;
}

export interface ClassificationResult {
  success: boolean;
  labels: ClassificationLabel[];
  error?: string;
}

export interface ClassificationOptions {
  minimumPrecision?: number;
  recallThreshold?: number;
  minimumConfidence?: number;
  maxResults?: number;
  confidenceThreshold?: number;
  useCustomModel?: boolean;
  /** iOS only: merge Google ML Kit labels with Vision results (default: true) */
  iosUseMlKit?: boolean;
}

export interface DescriptionResult {
  success: boolean;
  description: string;
  error?: string;
  modelStatus?: 'available' | 'downloading' | 'not_available';
}

export interface DescriptionOptions {
  maxResults?: number;
}

export type ModelStatus =
  | 'available'
  | 'downloading'
  | 'not_available'
  | 'downloadable'
  | 'not_supported';

export interface ModelDownloadProgress {
  progress: number;
  downloadedBytes: number;
  totalBytes: number;
}

/**
 * Classify an image and return labels with confidence scores.
 */
export function classifyImage(
  imageUri: string,
  options?: ClassificationOptions
): Promise<ClassificationResult>;

/**
 * Generate a natural language description of an image (Android only).
 */
export function describeImage(
  imageUri: string,
  options?: DescriptionOptions
): Promise<DescriptionResult>;

/**
 * Check the status of the GenAI description model (Android only).
 */
export function checkDescriptionModelStatus(): Promise<ModelStatus>;

/**
 * Download the GenAI description model (Android only).
 */
export function downloadDescriptionModel(
  onProgress?: (progress: number) => void
): Promise<boolean>;

/**
 * Check if the module is available on the current platform.
 */
export function isAvailable(): Promise<boolean>;

