package com.imagedescription

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.google.mlkit.genai.imagedescription.*
import kotlinx.coroutines.*
import kotlinx.coroutines.tasks.await
import java.io.File
import java.io.IOException

class ImageDescriptionModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private var imageLabeler: ImageLabeler? = null
    private var imageDescriber: ImageDescriber? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun getName(): String {
        return "ImageDescription"
    }

    override fun invalidate() {
        super.invalidate()
        scope.cancel()
        imageLabeler?.close()
        imageDescriber?.close()
        imageLabeler = null
        imageDescriber = null
    }

    @ReactMethod
    fun classifyImage(imageUri: String, options: ReadableMap, promise: Promise) {
        scope.launch {
            try {
                val bitmap = loadBitmapFromUri(imageUri)
                if (bitmap == null) {
                    promise.reject("image_load_failed", "Failed to load image from URI: $imageUri")
                    return@launch
                }

                val inputImage = InputImage.fromBitmap(bitmap, 0)
                
                // Configure labeler options
                val confidenceThreshold = if (options.hasKey("confidenceThreshold")) {
                    options.getDouble("confidenceThreshold").toFloat()
                } else {
                    0.5f
                }
                
                val labelerOptions = ImageLabelerOptions.Builder()
                    .setConfidenceThreshold(confidenceThreshold)
                    .build()

                // Get or create labeler
                if (imageLabeler == null) {
                    imageLabeler = ImageLabeling.getClient(labelerOptions)
                }

                val labels = imageLabeler!!.process(inputImage).await()
                
                // Apply max results filter if specified
                val maxResults = if (options.hasKey("maxResults") && !options.isNull("maxResults")) {
                    options.getInt("maxResults")
                } else {
                    0
                }

                val filteredLabels = if (maxResults > 0) {
                    labels.take(maxResults)
                } else {
                    labels
                }

                // Build result
                val labelsArray = Arguments.createArray()
                for ((index, label) in filteredLabels.withIndex()) {
                    val labelMap = Arguments.createMap().apply {
                        putString("identifier", label.text)
                        putDouble("confidence", label.confidence.toDouble())
                        putInt("index", index)
                    }
                    labelsArray.pushMap(labelMap)
                }

                val result = Arguments.createMap().apply {
                    putBoolean("success", true)
                    putArray("labels", labelsArray)
                }

                promise.resolve(result)

            } catch (e: Exception) {
                promise.reject("classification_failed", "Failed to classify image: ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun describeImage(imageUri: String, options: ReadableMap, promise: Promise) {
        scope.launch {
            try {
                // Check if describer is initialized
                if (imageDescriber == null) {
                    val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                    imageDescriber = ImageDescription.getClient(describerOptions)
                }

                val bitmap = loadBitmapFromUri(imageUri)
                if (bitmap == null) {
                    promise.reject("image_load_failed", "Failed to load image from URI: $imageUri")
                    return@launch
                }

                // Check feature status
                val status = imageDescriber!!.checkFeatureStatus().await()
                
                when (status) {
                    FeatureStatus.AVAILABLE -> {
                        // Model is ready, perform inference
                        val request = ImageDescriptionRequest.builder(bitmap).build()
                        
                        imageDescriber!!.runInference(request) { result ->
                            if (result != null) {
                                val resultMap = Arguments.createMap().apply {
                                    putBoolean("success", true)
                                    putString("description", result.text)
                                    putString("modelStatus", "available")
                                }
                                promise.resolve(resultMap)
                            } else {
                                val errorResult = Arguments.createMap().apply {
                                    putBoolean("success", false)
                                    putString("description", "")
                                    putString("error", "Failed to generate description")
                                    putString("modelStatus", "available")
                                }
                                promise.resolve(errorResult)
                            }
                        }
                    }
                    FeatureStatus.DOWNLOADABLE -> {
                        val errorResult = Arguments.createMap().apply {
                            putBoolean("success", false)
                            putString("description", "")
                            putString("error", "Model needs to be downloaded. Call downloadDescriptionModel() first.")
                            putString("modelStatus", "downloadable")
                        }
                        promise.resolve(errorResult)
                    }
                    else -> {
                        val errorResult = Arguments.createMap().apply {
                            putBoolean("success", false)
                            putString("description", "")
                            putString("error", "Model is not available: $status")
                            putString("modelStatus", "not_available")
                        }
                        promise.resolve(errorResult)
                    }
                }

            } catch (e: Exception) {
                promise.reject("description_failed", "Failed to describe image: ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun checkDescriptionModelStatus(promise: Promise) {
        scope.launch {
            try {
                // Initialize describer if needed
                if (imageDescriber == null) {
                    val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                    imageDescriber = ImageDescription.getClient(describerOptions)
                }

                val status = imageDescriber!!.checkFeatureStatus().await()
                
                val statusString = when (status) {
                    FeatureStatus.AVAILABLE -> "available"
                    FeatureStatus.DOWNLOADABLE -> "downloadable"
                    FeatureStatus.DOWNLOADING -> "downloading"
                    else -> "not_available"
                }
                
                promise.resolve(statusString)

            } catch (e: Exception) {
                promise.reject("status_check_failed", "Failed to check model status: ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun downloadDescriptionModel(promise: Promise) {
        scope.launch {
            try {
                // Initialize describer if needed
                if (imageDescriber == null) {
                    val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                    imageDescriber = ImageDescription.getClient(describerOptions)
                }

                val status = imageDescriber!!.checkFeatureStatus().await()
                
                if (status == FeatureStatus.AVAILABLE) {
                    promise.resolve(true)
                    return@launch
                }
                
                if (status != FeatureStatus.DOWNLOADABLE) {
                    promise.reject("download_failed", "Model cannot be downloaded. Status: $status")
                    return@launch
                }

                // Download the model
                var downloadSuccess = false
                
                imageDescriber!!.downloadFeature(object : DownloadCallback {
                    override fun onDownloadCompleted() {
                        downloadSuccess = true
                        promise.resolve(true)
                    }

                    override fun onDownloadFailed(exception: Exception) {
                        promise.reject("download_failed", "Model download failed: ${exception.message}", exception)
                    }

                    override fun onDownloadProgress(downloadedBytes: Long, totalBytes: Long) {
                        val progress = if (totalBytes > 0) {
                            downloadedBytes.toDouble() / totalBytes.toDouble()
                        } else {
                            0.0
                        }
                        
                        // Send progress event
                        val progressMap = Arguments.createMap().apply {
                            putDouble("progress", progress)
                            putDouble("downloadedBytes", downloadedBytes.toDouble())
                            putDouble("totalBytes", totalBytes.toDouble())
                        }
                        
                        sendEvent("ImageDescriptionModelDownloadProgress", progressMap)
                    }
                })

            } catch (e: Exception) {
                promise.reject("download_failed", "Failed to download model: ${e.message}", e)
            }
        }
    }

    @ReactMethod
    fun isAvailable(promise: Promise) {
        promise.resolve(true)
    }

    private fun loadBitmapFromUri(uriString: String): Bitmap? {
        return try {
            val uri = if (uriString.startsWith("file://")) {
                Uri.parse(uriString)
            } else {
                Uri.fromFile(File(uriString))
            }

            val path = uri.path ?: return null
            BitmapFactory.decodeFile(path)
        } catch (e: IOException) {
            null
        }
    }

    private fun sendEvent(eventName: String, params: WritableMap?) {
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }
}

