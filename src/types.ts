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
  minimumPrecision?: number; // 0.0-1.0, default 0.1
  recallThreshold?: number; // 0.0-1.0, default 0.8
  minimumConfidence?: number; // 0.0-1.0, filter results
  maxResults?: number; // Limit number of results
  confidenceThreshold?: number; // Android ML Kit labeling (0.0-1.0)
  useCustomModel?: boolean; // For future custom models
  // iOS-only: include Google ML Kit Image Labeling results alongside Vision
  // Defaults to true when omitted
  iosUseMlKit?: boolean;
}

export interface DescriptionResult {
  success: boolean;
  description: string;
  error?: string;
  modelStatus?: 'available' | 'downloading' | 'not_available';
}

export interface DescriptionOptions {
  maxResults?: number; // Android: limit number of descriptions
}

export type ModelStatus =
  | 'available'
  | 'downloading'
  | 'not_available'
  | 'downloadable'
  | 'not_supported';

export interface ModelDownloadProgress {
  progress: number; // 0.0-1.0
  downloadedBytes: number;
  totalBytes: number;
}

