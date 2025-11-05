import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  ScrollView,
  Image,
  ActivityIndicator,
  Platform,
  Alert,
} from 'react-native';
import {
  launchImageLibrary,
  ImageLibraryOptions,
} from 'react-native-image-picker';
import {
  classifyImage,
  describeImage,
  checkDescriptionModelStatus,
  downloadDescriptionModel,
  isAvailable,
  ClassificationResult,
  DescriptionResult,
  ModelStatus,
} from '@dariyd/react-native-image-description';

export default function App() {
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [classificationResult, setClassificationResult] =
    useState<ClassificationResult | null>(null);
  const [descriptionResult, setDescriptionResult] =
    useState<DescriptionResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [modelStatus, setModelStatus] = useState<ModelStatus>('not_available');
  const [downloadProgress, setDownloadProgress] = useState(0);
  const [isDownloading, setIsDownloading] = useState(false);
  const [moduleAvailable, setModuleAvailable] = useState(false);

  useEffect(() => {
    checkModuleAvailability();
    checkModelStatus();
  }, []);

  const checkModuleAvailability = async () => {
    const available = await isAvailable();
    setModuleAvailable(available);
  };

  const checkModelStatus = async () => {
    if (Platform.OS === 'android') {
      const status = await checkDescriptionModelStatus();
      setModelStatus(status);
    }
  };

  const handlePickImage = () => {
    const options: ImageLibraryOptions = {
      mediaType: 'photo',
      quality: 1,
    };

    launchImageLibrary(options, (response) => {
      if (response.didCancel) {
        return;
      }
      if (response.errorCode) {
        Alert.alert('Error', response.errorMessage || 'Failed to pick image');
        return;
      }

      const uri = response.assets?.[0]?.uri;
      if (uri) {
        setImageUri(uri);
        setClassificationResult(null);
        setDescriptionResult(null);
        handleClassifyImage(uri);
      }
    });
  };

  const handleClassifyImage = async (uri: string) => {
    setLoading(true);
    try {
      const result = await classifyImage(uri, {
        minimumConfidence: 0.5,
        maxResults: 15,
        iosUseMlKit: true,
      });
      console.log('result', result);
      setClassificationResult(result);
    } catch (error) {
      Alert.alert('Error', `Classification failed: ${error}`);
    } finally {
      setLoading(false);
    }
  };

  const handleDescribeImage = async () => {
    if (!imageUri) {
      Alert.alert('Error', 'Please select an image first');
      return;
    }

    if (Platform.OS === 'ios') {
      Alert.alert(
        'Not Available',
        'Image description is not available on iOS. Classification labels are shown instead.'
      );
      return;
    }

    // Check model status
    const status = await checkDescriptionModelStatus();
    setModelStatus(status);

    if (status === 'downloadable') {
      Alert.alert(
        'Model Required',
        'The image description model needs to be downloaded first. Would you like to download it now?',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Download', onPress: handleDownloadModel },
        ]
      );
      return;
    }

    if (status !== 'available') {
      Alert.alert('Error', `Model is not available. Status: ${status}`);
      return;
    }

    setLoading(true);
    try {
      const result = await describeImage(imageUri);
      setDescriptionResult(result);
    } catch (error) {
      Alert.alert('Error', `Description failed: ${error}`);
    } finally {
      setLoading(false);
    }
  };

  const handleDownloadModel = async () => {
    setIsDownloading(true);
    setDownloadProgress(0);

    try {
      const success = await downloadDescriptionModel((progress) => {
        setDownloadProgress(progress);
      });

      if (success) {
        Alert.alert('Success', 'Model downloaded successfully!');
        setModelStatus('available');
      } else {
        Alert.alert('Error', 'Failed to download model');
      }
    } catch (error) {
      Alert.alert('Error', `Download failed: ${error}`);
    } finally {
      setIsDownloading(false);
      setDownloadProgress(0);
    }
  };

  const renderClassificationResults = () => {
    if (!classificationResult) return null;

    if (!classificationResult.success) {
      return (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>
            {classificationResult.error || 'Classification failed'}
          </Text>
        </View>
      );
    }

    if (classificationResult.labels.length === 0) {
      return (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>No labels found</Text>
        </View>
      );
    }

    return (
      <View style={styles.resultsContainer}>
        <Text style={styles.resultsTitle}>Classification Results:</Text>
        {classificationResult.labels.map((label, index) => (
          <View key={index} style={styles.labelContainer}>
            <View style={styles.labelHeader}>
              <Text style={styles.labelText}>{label.identifier}</Text>
              <Text style={styles.confidenceText}>
                {(label.confidence * 100).toFixed(1)}%
              </Text>
            </View>
            <View style={styles.confidenceBar}>
              <View
                style={[
                  styles.confidenceFill,
                  { width: `${label.confidence * 100}%` },
                ]}
              />
            </View>
          </View>
        ))}
      </View>
    );
  };

  const renderDescriptionResult = () => {
    if (!descriptionResult) return null;

    if (!descriptionResult.success) {
      return (
        <View style={styles.errorContainer}>
          <Text style={styles.errorText}>
            {descriptionResult.error || 'Description failed'}
          </Text>
        </View>
      );
    }

    return (
      <View style={styles.descriptionContainer}>
        <Text style={styles.resultsTitle}>Description:</Text>
        <Text style={styles.descriptionText}>
          {descriptionResult.description}
        </Text>
      </View>
    );
  };

  const renderModelStatus = () => {
    if (Platform.OS !== 'android') return null;

    return (
      <View style={styles.modelStatusContainer}>
        <Text style={styles.modelStatusText}>
          Model Status: <Text style={styles.statusValue}>{modelStatus}</Text>
        </Text>
        {modelStatus === 'downloadable' && (
          <TouchableOpacity
            style={styles.downloadButton}
            onPress={handleDownloadModel}
            disabled={isDownloading}
          >
            <Text style={styles.downloadButtonText}>
              {isDownloading ? 'Downloading...' : 'Download Model'}
            </Text>
          </TouchableOpacity>
        )}
        {isDownloading && (
          <View style={styles.progressContainer}>
            <View style={styles.progressBar}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${downloadProgress * 100}%` },
                ]}
              />
            </View>
            <Text style={styles.progressText}>
              {(downloadProgress * 100).toFixed(0)}%
            </Text>
          </View>
        )}
      </View>
    );
  };

  if (!moduleAvailable) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>
          Image Description module is not available on this device
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollView}>
        <Text style={styles.header}>Image Description Example</Text>

        <TouchableOpacity style={styles.button} onPress={handlePickImage}>
          <Text style={styles.buttonText}>Pick Image</Text>
        </TouchableOpacity>

        {imageUri && (
          <View style={styles.imageContainer}>
            <Image source={{ uri: imageUri }} style={styles.image} />
          </View>
        )}

        {Platform.OS === 'android' && renderModelStatus()}

        {imageUri && (
          <TouchableOpacity
            style={[
              styles.button,
              styles.describeButton,
              Platform.OS === 'ios' && styles.disabledButton,
            ]}
            onPress={handleDescribeImage}
            disabled={loading || Platform.OS === 'ios'}
          >
            <Text style={styles.buttonText}>
              {Platform.OS === 'ios'
                ? 'Description (Android Only)'
                : 'Describe Image'}
            </Text>
          </TouchableOpacity>
        )}

        {loading && <ActivityIndicator size="large" color="#007AFF" />}

        {renderClassificationResults()}
        {renderDescriptionResult()}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollView: {
    flex: 1,
    padding: 20,
  },
  header: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    marginTop: 40,
    textAlign: 'center',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 10,
    alignItems: 'center',
    marginBottom: 15,
  },
  describeButton: {
    backgroundColor: '#34C759',
  },
  disabledButton: {
    backgroundColor: '#ccc',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  imageContainer: {
    alignItems: 'center',
    marginVertical: 20,
  },
  image: {
    width: 300,
    height: 300,
    borderRadius: 10,
    resizeMode: 'contain',
  },
  resultsContainer: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 10,
    marginTop: 20,
  },
  resultsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 15,
  },
  labelContainer: {
    marginBottom: 15,
  },
  labelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 5,
  },
  labelText: {
    fontSize: 16,
    fontWeight: '500',
  },
  confidenceText: {
    fontSize: 16,
    color: '#007AFF',
    fontWeight: '600',
  },
  confidenceBar: {
    height: 8,
    backgroundColor: '#e0e0e0',
    borderRadius: 4,
    overflow: 'hidden',
  },
  confidenceFill: {
    height: '100%',
    backgroundColor: '#007AFF',
  },
  descriptionContainer: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 10,
    marginTop: 20,
  },
  descriptionText: {
    fontSize: 16,
    lineHeight: 24,
    color: '#333',
  },
  errorContainer: {
    backgroundColor: '#ffebee',
    padding: 15,
    borderRadius: 10,
    marginTop: 20,
  },
  errorText: {
    color: '#c62828',
    fontSize: 14,
  },
  emptyContainer: {
    padding: 20,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#666',
  },
  modelStatusContainer: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 10,
    marginBottom: 15,
  },
  modelStatusText: {
    fontSize: 16,
    marginBottom: 10,
  },
  statusValue: {
    fontWeight: 'bold',
    color: '#007AFF',
  },
  downloadButton: {
    backgroundColor: '#FF9500',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  downloadButtonText: {
    color: 'white',
    fontSize: 14,
    fontWeight: '600',
  },
  progressContainer: {
    marginTop: 10,
  },
  progressBar: {
    height: 6,
    backgroundColor: '#e0e0e0',
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#FF9500',
  },
  progressText: {
    marginTop: 5,
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
  },
});
