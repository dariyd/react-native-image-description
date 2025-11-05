package com.imagedescription

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
// GenAI Image Description - use wildcard import due to beta API instability
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
        try {
            // Initialize describer if needed
            if (imageDescriber == null) {
                val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                imageDescriber = ImageDescription.getClient(describerOptions)
            }

            val bitmap = loadBitmapFromUri(imageUri)
            if (bitmap == null) {
                promise.reject("image_load_failed", "Failed to load image from URI: $imageUri")
                return
            }

            val statusFuture = imageDescriber!!.checkFeatureStatus()
            val executor = ContextCompat.getMainExecutor(reactContext)
            statusFuture.addListener({
                try {
                    val status = statusFuture.get()
                    when (status) {
                        FeatureStatus.AVAILABLE -> {
                            val request = ImageDescriptionRequest.builder(bitmap).build()
                            val inferenceFuture = imageDescriber!!.runInference(request)
                            inferenceFuture.addListener({
                                try {
                                    val result = inferenceFuture.get()
                                    val description = result.description
                                    val map = Arguments.createMap().apply {
                                        putBoolean("success", true)
                                        putString("description", description)
                                        putString("modelStatus", "available")
                                    }
                                    promise.resolve(map)
                                } catch (e: Exception) {
                                    promise.reject("description_failed", "Failed inference: ${e.message}", e)
                                }
                            }, executor)
                        }
                        FeatureStatus.DOWNLOADABLE, FeatureStatus.DOWNLOADING -> {
                            val map = Arguments.createMap().apply {
                                putBoolean("success", false)
                                putString("description", "")
                                putString("error", "Model needs to be downloaded. Call downloadDescriptionModel() first.")
                                putString("modelStatus", if (status == FeatureStatus.DOWNLOADING) "downloading" else "downloadable")
                            }
                            promise.resolve(map)
                        }
                        else -> {
                            val map = Arguments.createMap().apply {
                                putBoolean("success", false)
                                putString("description", "")
                                putString("error", "Model is not available: $status")
                                putString("modelStatus", "not_available")
                            }
                            promise.resolve(map)
                        }
                    }
                } catch (e: Exception) {
                    promise.reject("status_check_failed", "Failed to check model status: ${e.message}", e)
                }
            }, executor)
        } catch (e: Exception) {
            promise.reject("description_failed", "Failed to describe image: ${e.message}", e)
        }
    }

    @ReactMethod
    fun checkDescriptionModelStatus(promise: Promise) {
        try {
            if (imageDescriber == null) {
                val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                imageDescriber = ImageDescription.getClient(describerOptions)
            }

            val future = imageDescriber!!.checkFeatureStatus()
            val executor = ContextCompat.getMainExecutor(reactContext)
            future.addListener({
                try {
                    val status = future.get()
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
            }, executor)
        } catch (e: Exception) {
            promise.reject("status_check_failed", "Failed to check model status: ${e.message}", e)
        }
    }

    @ReactMethod
    fun downloadDescriptionModel(promise: Promise) {
        try {
            if (imageDescriber == null) {
                val describerOptions = ImageDescriberOptions.builder(reactContext).build()
                imageDescriber = ImageDescription.getClient(describerOptions)
            }

            val statusFuture = imageDescriber!!.checkFeatureStatus()
            val executor = ContextCompat.getMainExecutor(reactContext)
            statusFuture.addListener({
                try {
                    val status = statusFuture.get()
                    if (status == FeatureStatus.AVAILABLE) {
                        promise.resolve(true)
                        return@addListener
                    }
                    if (status != FeatureStatus.DOWNLOADABLE && status != FeatureStatus.DOWNLOADING) {
                        promise.reject("download_failed", "Model cannot be downloaded. Status: $status")
                        return@addListener
                    }

                    imageDescriber!!.downloadFeature(object : DownloadCallback {
                        override fun onDownloadCompleted() {
                            promise.resolve(true)
                        }

                        override fun onDownloadFailed(exception: GenAiException) {
                            promise.reject("download_failed", "Model download failed: ${exception.message}", exception)
                        }

                        override fun onDownloadProgress(totalBytesDownloaded: Long) {
                            val progressMap = Arguments.createMap().apply {
                                putDouble("downloadedBytes", totalBytesDownloaded.toDouble())
                            }
                            sendEvent("ImageDescriptionModelDownloadProgress", progressMap)
                        }

                        override fun onDownloadStarted(bytesToDownload: Long) {
                            val progressMap = Arguments.createMap().apply {
                                putDouble("totalBytes", bytesToDownload.toDouble())
                            }
                            sendEvent("ImageDescriptionModelDownloadProgress", progressMap)
                        }
                    })
                } catch (e: Exception) {
                    promise.reject("download_failed", "Failed to check model status: ${e.message}", e)
                }
            }, executor)
        } catch (e: Exception) {
            promise.reject("download_failed", "Failed to download model: ${e.message}", e)
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

