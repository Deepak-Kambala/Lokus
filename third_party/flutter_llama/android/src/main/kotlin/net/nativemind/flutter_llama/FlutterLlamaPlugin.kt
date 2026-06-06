package net.nativemind.flutter_llama

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

/**
 * FlutterLlamaPlugin - плагин для работы с llama.cpp моделями на Android
 * 
 * Поддерживает:
 * - Загрузку GGUF моделей
 * - GPU ускорение через Vulkan/OpenCL
 * - Потоковую и обычную генерацию
 */
class FlutterLlamaPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val TAG = "FlutterLlama"
        private const val CHANNEL_NAME = "flutter_llama"
        private const val EVENT_CHANNEL_NAME = "flutter_llama/stream"
        private const val GGUF_MAGIC = "GGUF"
        private const val MIN_SAFE_CONTEXT_SIZE = 512
        private const val LOW_MEMORY_CONTEXT_SIZE = 1024
        private const val LOW_MEMORY_BATCH_SIZE = 32
        private const val DEFAULT_BATCH_SIZE = 64
        private const val MEMORY_HEADROOM_BYTES = 512L * 1024L * 1024L
        private var nativeLibrariesLoaded = false
        private var nativeLoadError: String? = null

        init {
            try {
                val libraries = listOf(
                    "c++_shared",
                    "ggml",
                    "ggml-base",
                    "ggml-cpu",
                    "llama",
                    "flutter_llama_bridge"
                )
                libraries.forEach { System.loadLibrary(it) }
                nativeLibrariesLoaded = true
                Log.d(TAG, "Native libraries loaded successfully")
            } catch (e: UnsatisfiedLinkError) {
                nativeLoadError = e.message
                Log.e(TAG, "Failed to load native libraries: ${e.message}", e)
            }
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var appContext: Context
    @Volatile private var eventSink: EventChannel.EventSink? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var modelLoaded = false
    private var modelPath: String? = null
    @Volatile private var shouldStop = false

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
        
        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "loadModel" -> loadModel(call, result)
            "generate" -> generate(call, result)
            "generateStream" -> generateStream(call, result)
            "unloadModel" -> unloadModel(result)
            "getModelInfo" -> getModelInfo(result)
            "stopGeneration" -> stopGeneration(result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
    }

    // MARK: - EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        shouldStop = true
    }

    // MARK: - Load Model

    private fun loadModel(call: MethodCall, result: Result) {
        executor.execute {
            try {
                if (!nativeLibrariesLoaded) {
                    mainHandler.post {
                        result.error(
                            "NATIVE_LIBS_MISSING",
                            "Required llama.cpp native libraries are missing or could not be loaded",
                            nativeLoadError
                        )
                    }
                    return@execute
                }

                val modelPath = call.argument<String>("modelPath")
                if (modelPath == null) {
                    mainHandler.post {
                        result.error("INVALID_ARGS", "Missing modelPath", null)
                    }
                    return@execute
                }

                val nThreads = call.argument<Int>("nThreads") ?: 4
                val nGpuLayers = call.argument<Int>("nGpuLayers") ?: 0
                val contextSize = call.argument<Int>("contextSize") ?: 2048
                val batchSize = call.argument<Int>("batchSize") ?: 512
                val useGpu = call.argument<Boolean>("useGpu") ?: true
                val verbose = call.argument<Boolean>("verbose") ?: false

                val validationError = validateModelFile(modelPath)
                if (validationError != null) {
                    mainHandler.post {
                        result.error(validationError.code, validationError.message, null)
                    }
                    return@execute
                }

                val file = File(modelPath)
                val memory = getMemorySnapshot()
                Log.i(
                    TAG,
                    "Loading model path=$modelPath size=${file.length()} " +
                        "abi=${Build.SUPPORTED_ABIS.joinToString()} " +
                        "sdk=${Build.VERSION.SDK_INT} manufacturer=${Build.MANUFACTURER} " +
                        "model=${Build.MODEL} availMem=${memory?.availMem} " +
                        "lowMemory=${memory?.lowMemory} threshold=${memory?.threshold}"
                )

                this.modelPath = modelPath

                val attempts = buildLoadAttempts(
                    requestedThreads = nThreads,
                    requestedGpuLayers = nGpuLayers,
                    requestedContextSize = contextSize,
                    requestedBatchSize = batchSize,
                    requestedUseGpu = useGpu,
                    fileSize = file.length(),
                    memory = memory
                )

                var success = false
                var lastError: Throwable? = null
                for (attempt in attempts) {
                    try {
                        Log.i(
                            TAG,
                            "Model load attempt ${attempt.label}: " +
                                "threads=${attempt.threads}, gpuLayers=${attempt.gpuLayers}, " +
                                "context=${attempt.contextSize}, batch=${attempt.batchSize}, " +
                                "useGpu=${attempt.useGpu}"
                        )
                        success = nativeInitModel(
                            modelPath,
                            attempt.threads,
                            attempt.gpuLayers,
                            attempt.contextSize,
                            attempt.batchSize,
                            attempt.useGpu,
                            verbose
                        )
                        if (success) {
                            Log.i(TAG, "Model load attempt succeeded: ${attempt.label}")
                            break
                        }
                        nativeFreeModel()
                    } catch (t: Throwable) {
                        lastError = t
                        Log.e(TAG, "Model load attempt failed: ${attempt.label}", t)
                        try {
                            nativeFreeModel()
                        } catch (cleanup: Throwable) {
                            Log.w(TAG, "Cleanup after failed load attempt failed", cleanup)
                        }
                    }
                }

                modelLoaded = success

                mainHandler.post {
                    if (success) {
                        Log.d(TAG, "Model loaded: $modelPath")
                        Log.d(TAG, "GPU layers: $nGpuLayers, threads: $nThreads, context: $contextSize")
                        result.success(true)
                    } else {
                        val details = lastError?.message ?: "All load attempts failed"
                        result.error("INIT_FAILED", "Failed to initialize model", details)
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error loading model", e)
                mainHandler.post {
                    result.error("EXCEPTION", "Error loading model: ${e.message}", null)
                }
            }
        }
    }

    // MARK: - Generate (blocking)

    private fun generate(call: MethodCall, result: Result) {
        if (!nativeLibrariesLoaded) {
            result.error("NATIVE_LIBS_MISSING", "Native libraries are not loaded", nativeLoadError)
            return
        }
        if (!modelLoaded) {
            result.error("MODEL_NOT_LOADED", "Model not loaded", null)
            return
        }

        executor.execute {
            try {
                val prompt = call.argument<String>("prompt")
                if (prompt == null) {
                    mainHandler.post {
                        result.error("INVALID_ARGS", "Missing prompt", null)
                    }
                    return@execute
                }

                val temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.8f
                val topP = call.argument<Double>("topP")?.toFloat() ?: 0.95f
                val topK = call.argument<Int>("topK") ?: 40
                val maxTokens = call.argument<Int>("maxTokens") ?: 512
                val repeatPenalty = call.argument<Double>("repeatPenalty")?.toFloat() ?: 1.1f

                shouldStop = false
                val startTime = System.currentTimeMillis()

                // Generate through JNI
                val generationResult = nativeGenerate(
                    prompt,
                    temperature,
                    topP,
                    topK,
                    maxTokens,
                    repeatPenalty
                )

                val generationTime = System.currentTimeMillis() - startTime

                mainHandler.post {
                    if (generationResult != null) {
                        val response = hashMapOf(
                            "text" to generationResult.text,
                            "tokensGenerated" to generationResult.tokensGenerated,
                            "generationTimeMs" to generationTime
                        )
                        Log.d(TAG, "Generated: ${generationResult.tokensGenerated} tokens in ${generationTime}ms")
                        result.success(response)
                    } else {
                        result.error("GENERATION_FAILED", "Failed to generate response", null)
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error generating", e)
                mainHandler.post {
                    result.error("EXCEPTION", "Error generating: ${e.message}", null)
                }
            }
        }
    }

    // MARK: - Generate Stream

    private fun generateStream(call: MethodCall, result: Result) {
        if (!nativeLibrariesLoaded) {
            result.error("NATIVE_LIBS_MISSING", "Native libraries are not loaded", nativeLoadError)
            return
        }
        if (!modelLoaded) {
            result.error("MODEL_NOT_LOADED", "Model not loaded", null)
            return
        }

        val sink = eventSink
        if (sink == null) {
            result.error("NO_EVENT_SINK", "Event channel not initialized", null)
            return
        }

        executor.execute {
            var streamInitialized = false
            var stopped = false
            try {
                val prompt = call.argument<String>("prompt")
                if (prompt == null) {
                    mainHandler.post {
                        result.error("INVALID_ARGS", "Missing prompt", null)
                    }
                    return@execute
                }

                val temperature = call.argument<Double>("temperature")?.toFloat() ?: 0.8f
                val topP = call.argument<Double>("topP")?.toFloat() ?: 0.95f
                val topK = call.argument<Int>("topK") ?: 40
                val maxTokens = call.argument<Int>("maxTokens") ?: 512
                val repeatPenalty = call.argument<Double>("repeatPenalty")?.toFloat() ?: 1.1f
                val requestId = call.argument<Int>("requestId") ?: 0

                shouldStop = false

                val initialized = nativeGenerateStreamInit(
                    prompt,
                    temperature,
                    topP,
                    topK,
                    maxTokens,
                    repeatPenalty
                )
                if (!initialized) {
                    mainHandler.post {
                        result.error(
                            "STREAM_INIT_FAILED",
                            "Failed to initialize streaming generation",
                            null
                        )
                    }
                    return@execute
                }
                streamInitialized = true

                // Stream tokens one by one
                while (!shouldStop) {
                    val token = nativeGenerateStreamNext()
                    if (token != null) {
                        val stoppedBeforePost = shouldStop
                        mainHandler.post {
                            if (!stoppedBeforePost) {
                                sink.success(
                                    hashMapOf(
                                        "requestId" to requestId,
                                        "token" to token
                                    )
                                )
                            }
                        }
                    } else {
                        break
                    }
                }

                stopped = shouldStop

                mainHandler.post {
                    if (!stopped) {
                        sink.success(
                            hashMapOf(
                                "requestId" to requestId,
                                "done" to true
                            )
                        )
                    }
                    result.success(null)
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error in streaming generation", e)
                mainHandler.post {
                    sink.error("EXCEPTION", "Error in streaming: ${e.message}", null)
                    result.error("EXCEPTION", "Error in streaming: ${e.message}", null)
                }
            } finally {
                if (streamInitialized) {
                    try {
                        nativeGenerateStreamEnd()
                    } catch (e: Throwable) {
                        Log.e(TAG, "Error ending streaming generation", e)
                    }
                }
            }
        }
    }

    // MARK: - Unload Model

    private fun unloadModel(result: Result) {
        try {
            if (modelLoaded && nativeLibrariesLoaded) {
                nativeFreeModel()
                Log.d(TAG, "Model unloaded")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error unloading model", e)
        } finally {
            modelLoaded = false
            modelPath = null
        }
        result.success(null)
    }

    // MARK: - Get Model Info

    private fun getModelInfo(result: Result) {
        if (!modelLoaded || modelPath == null) {
            result.success(null)
            return
        }

        try {
            val info = nativeGetModelInfo()
            if (info != null) {
                val infoMap = hashMapOf(
                    "modelPath" to modelPath!!,
                    "nParams" to info.nParams,
                    "nLayers" to info.nLayers,
                    "contextSize" to info.contextSize
                )
                result.success(infoMap)
            } else {
                result.success(null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error getting model info", e)
            result.success(null)
        }
    }

    // MARK: - Stop Generation

    private fun stopGeneration(result: Result) {
        shouldStop = true
        if (nativeLibrariesLoaded) {
            try {
                nativeStopGeneration()
            } catch (e: Throwable) {
                Log.e(TAG, "Error stopping generation", e)
            }
        }
        result.success(null)
    }

    private fun validateModelFile(modelPath: String): ValidationError? {
        val file = File(modelPath)
        if (!file.exists()) {
            return ValidationError("MODEL_NOT_FOUND", "Model file not found: $modelPath")
        }
        if (!file.isFile) {
            return ValidationError("MODEL_NOT_FILE", "Model path is not a file: $modelPath")
        }
        if (!file.canRead()) {
            return ValidationError("MODEL_PERMISSION_DENIED", "Model file is not readable: $modelPath")
        }
        if (file.length() < 4L) {
            return ValidationError("MODEL_EMPTY", "Model file is empty or incomplete: $modelPath")
        }
        return try {
            FileInputStream(file).use { input ->
                val header = ByteArray(4)
                val read = input.read(header)
                val magic = header.toString(Charsets.US_ASCII)
                if (read != 4 || magic != GGUF_MAGIC) {
                    ValidationError("MODEL_INVALID", "Model file is not a valid GGUF file: $modelPath")
                } else {
                    null
                }
            }
        } catch (e: SecurityException) {
            ValidationError("MODEL_PERMISSION_DENIED", "Cannot read model file: ${e.message}")
        } catch (e: Exception) {
            ValidationError("MODEL_READ_FAILED", "Cannot validate model file: ${e.message}")
        }
    }

    private fun buildLoadAttempts(
        requestedThreads: Int,
        requestedGpuLayers: Int,
        requestedContextSize: Int,
        requestedBatchSize: Int,
        requestedUseGpu: Boolean,
        fileSize: Long,
        memory: ActivityManager.MemoryInfo?
    ): List<LoadAttempt> {
        val cpuCount = max(1, Runtime.getRuntime().availableProcessors())
        val safeThreads = requestedThreads.coerceIn(1, min(cpuCount, 4))
        val safeContext = requestedContextSize.coerceAtLeast(MIN_SAFE_CONTEXT_SIZE)
        val safeBatch = requestedBatchSize.coerceIn(1, DEFAULT_BATCH_SIZE)
        val lowMemory = memory?.lowMemory == true ||
            (memory?.availMem ?: Long.MAX_VALUE) < fileSize + MEMORY_HEADROOM_BYTES

        val attempts = linkedMapOf<String, LoadAttempt>()
        fun add(attempt: LoadAttempt) {
            val key = "${attempt.useGpu}:${attempt.gpuLayers}:${attempt.contextSize}:${attempt.batchSize}:${attempt.threads}"
            attempts.putIfAbsent(key, attempt)
        }

        if (requestedUseGpu && requestedGpuLayers != 0) {
            add(
                LoadAttempt(
                    label = "requested-accelerated",
                    threads = safeThreads,
                    gpuLayers = requestedGpuLayers,
                    contextSize = safeContext,
                    batchSize = safeBatch,
                    useGpu = true
                )
            )
        }

        add(
            LoadAttempt(
                label = "cpu",
                threads = safeThreads,
                gpuLayers = 0,
                contextSize = safeContext,
                batchSize = safeBatch,
                useGpu = false
            )
        )

        if (lowMemory || safeContext > LOW_MEMORY_CONTEXT_SIZE || safeBatch > LOW_MEMORY_BATCH_SIZE) {
            add(
                LoadAttempt(
                    label = "cpu-low-memory",
                    threads = min(safeThreads, 2),
                    gpuLayers = 0,
                    contextSize = min(safeContext, LOW_MEMORY_CONTEXT_SIZE),
                    batchSize = min(safeBatch, LOW_MEMORY_BATCH_SIZE),
                    useGpu = false
                )
            )
        }

        return attempts.values.toList()
    }

    private fun getMemorySnapshot(): ActivityManager.MemoryInfo? {
        return try {
            val activityManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            ActivityManager.MemoryInfo().also { activityManager.getMemoryInfo(it) }
        } catch (e: Throwable) {
            Log.w(TAG, "Unable to read Android memory info", e)
            null
        }
    }

    // MARK: - Native Methods (JNI)

    private external fun nativeInitModel(
        modelPath: String,
        nThreads: Int,
        nGpuLayers: Int,
        contextSize: Int,
        batchSize: Int,
        useGpu: Boolean,
        verbose: Boolean
    ): Boolean

    private external fun nativeGenerate(
        prompt: String,
        temperature: Float,
        topP: Float,
        topK: Int,
        maxTokens: Int,
        repeatPenalty: Float
    ): GenerationResult?

    private external fun nativeGenerateStreamInit(
        prompt: String,
        temperature: Float,
        topP: Float,
        topK: Int,
        maxTokens: Int,
        repeatPenalty: Float
    ): Boolean

    private external fun nativeGenerateStreamNext(): String?

    private external fun nativeGenerateStreamEnd()

    private external fun nativeGetModelInfo(): ModelInfo?

    private external fun nativeFreeModel()

    private external fun nativeStopGeneration()

    // Data classes for JNI results
    data class GenerationResult(
        val text: String,
        val tokensGenerated: Int
    )

    data class ModelInfo(
        val nParams: Long,
        val nLayers: Int,
        val contextSize: Int
    )

    data class ValidationError(
        val code: String,
        val message: String
    )

    data class LoadAttempt(
        val label: String,
        val threads: Int,
        val gpuLayers: Int,
        val contextSize: Int,
        val batchSize: Int,
        val useGpu: Boolean
    )
}
