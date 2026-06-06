/*
 * Flutter Llama - JNI Bridge for Android
 * 
 * This file provides JNI bindings between Kotlin and llama.cpp
 * Updated for latest llama.cpp API
 */

#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <chrono>
#include <algorithm>
#include <cstdio>
#include <android/log.h>

#define LOG_TAG "FlutterLlamaBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Include llama.cpp headers
#include "llama.h"

// Global state
static llama_model* g_model = nullptr;
static llama_context* g_context = nullptr;
static const llama_vocab* g_vocab = nullptr;
static llama_sampler* g_sampler = nullptr;
static std::mutex g_mutex;
static bool g_should_stop = false;
static int g_stream_n_pos = 0;
static int g_stream_max_tokens = 0;
static int g_stream_generated = 0;
static bool g_stream_done = false;
static std::string g_last_error;

static void set_last_error(const std::string& message) {
    g_last_error = message;
    LOGE("%s", message.c_str());
}

static void throw_java_exception(JNIEnv* env, const std::string& message) {
    set_last_error(message);
    jclass exception_class = env->FindClass("java/lang/IllegalStateException");
    if (exception_class) {
        env->ThrowNew(exception_class, message.c_str());
    }
}

static std::string format_error(const char* format, const char* value) {
    char buffer[1024] = {0};
    std::snprintf(buffer, sizeof(buffer), format, value);
    return std::string(buffer);
}

static std::string format_error(const char* format, int first, int second) {
    char buffer[1024] = {0};
    std::snprintf(buffer, sizeof(buffer), format, first, second);
    return std::string(buffer);
}

static uint32_t new_seed() {
    return (uint32_t) std::chrono::high_resolution_clock::now()
            .time_since_epoch()
            .count();
}

static void reset_context_memory() {
    if (g_context) {
        llama_memory_clear(llama_get_memory(g_context), true);
    }
}

static std::string sanitize_utf8(const std::string& input) {
    std::string output;
    output.reserve(input.size());

    for (size_t i = 0; i < input.size();) {
        unsigned char c = static_cast<unsigned char>(input[i]);
        size_t len = 0;

        if (c <= 0x7F) {
            output.push_back(static_cast<char>(c));
            i++;
            continue;
        } else if ((c & 0xE0) == 0xC0) {
            len = 2;
        } else if ((c & 0xF0) == 0xE0) {
            len = 3;
        } else if ((c & 0xF8) == 0xF0) {
            len = 4;
        } else {
            output.push_back('?');
            i++;
            continue;
        }

        if (i + len > input.size()) {
            output.push_back('?');
            break;
        }

        bool valid = true;
        for (size_t j = 1; j < len; j++) {
            unsigned char cc = static_cast<unsigned char>(input[i + j]);
            if ((cc & 0xC0) != 0x80) {
                valid = false;
                break;
            }
        }

        if (valid) {
            output.append(input, i, len);
            i += len;
        } else {
            output.push_back('?');
            i++;
        }
    }

    return output;
}

static jstring safe_new_string_utf(JNIEnv* env, const std::string& value) {
    std::string sanitized = sanitize_utf8(value);
    return env->NewStringUTF(sanitized.c_str());
}

static bool token_to_piece(llama_token token, std::string& out) {
    if (!g_vocab) {
        return false;
    }

    char stack_buffer[256] = {0};
    int n = llama_token_to_piece(
        g_vocab,
        token,
        stack_buffer,
        sizeof(stack_buffer) - 1,
        0,
        true
    );
    if (n > 0 && n < static_cast<int>(sizeof(stack_buffer))) {
        out.assign(stack_buffer, n);
        return true;
    }

    if (n == 0) {
        out.clear();
        return true;
    }

    const int required = n < 0 ? -n : n + 1;
    if (required <= 0 || required > 16384) {
        return false;
    }

    std::vector<char> buffer(static_cast<size_t>(required) + 1);
    n = llama_token_to_piece(
        g_vocab,
        token,
        buffer.data(),
        static_cast<int>(buffer.size()) - 1,
        0,
        true
    );
    if (n < 0 || n >= static_cast<int>(buffer.size())) {
        return false;
    }

    out.assign(buffer.data(), n);
    return true;
}

static bool decode_prompt_tokens(const std::vector<llama_token>& tokens) {
    if (!g_context || tokens.empty()) {
        return false;
    }

    const int chunk_size = 64;
    for (size_t offset = 0; offset < tokens.size(); offset += chunk_size) {
        const int n_tokens = static_cast<int>(std::min<size_t>(chunk_size, tokens.size() - offset));
        llama_batch batch = llama_batch_get_one(
            const_cast<llama_token*>(tokens.data() + offset),
            n_tokens
        );
        if (llama_decode(g_context, batch) != 0) {
            LOGE("Failed to decode prompt chunk at offset=%zu size=%d", offset, n_tokens);
            return false;
        }
    }

    return true;
}

extern "C" {

// Initialize and load model
JNIEXPORT jboolean JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeInitModel(
    JNIEnv* env,
    jobject thiz,
    jstring model_path,
    jint n_threads,
    jint n_gpu_layers,
    jint context_size,
    jint batch_size,
    jboolean use_gpu,
    jboolean verbose
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    const char* path = env->GetStringUTFChars(model_path, nullptr);
    if (!path) {
        throw_java_exception(env, "Model path string could not be read");
        return JNI_FALSE;
    }
    
    LOGI("Initializing model: %s", path);
    LOGI("Threads: %d, GPU layers: %d, Context: %d", n_threads, n_gpu_layers, context_size);
    
    // Free existing model if any
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    if (g_model) {
        llama_free_model(g_model);
        g_model = nullptr;
    }
    
    // Load dynamic backends
    ggml_backend_load_all();
    
    // Set up model parameters
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = use_gpu ? n_gpu_layers : 0;
    
    // Load model
    g_model = llama_model_load_from_file(path, model_params);
    if (!g_model) {
        const std::string error = format_error("Failed to load model from: %s", path);
        g_vocab = nullptr;
        env->ReleaseStringUTFChars(model_path, path);
        throw_java_exception(env, error);
        return JNI_FALSE;
    }
    
    // Get vocab
    g_vocab = llama_model_get_vocab(g_model);
    
    // Create context
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = context_size;
    ctx_params.n_batch = batch_size;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;
    
    g_context = llama_init_from_model(g_model, ctx_params);
    if (!g_context) {
        const std::string error = "Failed to create llama context";
        llama_free_model(g_model);
        g_model = nullptr;
        g_vocab = nullptr;
        env->ReleaseStringUTFChars(model_path, path);
        throw_java_exception(env, error);
        return JNI_FALSE;
    }
    
    // Initialize sampler chain
    auto sparams = llama_sampler_chain_default_params();
    sparams.no_perf = false;
    g_sampler = llama_sampler_chain_init(sparams);
    
    // Add samplers
    llama_sampler_chain_add(g_sampler, llama_sampler_init_penalties(64, 1.1f, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(0.95f, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(new_seed()));
    
    LOGI("Model loaded successfully");
    LOGI("Context size: %d", llama_n_ctx(g_context));
    
    env->ReleaseStringUTFChars(model_path, path);
    return JNI_TRUE;
}

// Generate text
JNIEXPORT jobject JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeGenerate(
    JNIEnv* env,
    jobject thiz,
    jstring prompt,
    jfloat temperature,
    jfloat top_p,
    jint top_k,
    jint max_tokens,
    jfloat repeat_penalty
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (!g_model || !g_context || !g_vocab) {
        throw_java_exception(env, "Model not loaded");
        return nullptr;
    }
    
    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) {
        throw_java_exception(env, "Prompt string could not be read");
        return nullptr;
    }
    LOGI("Generating text");
    
    std::string prompt_text(prompt_str);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    reset_context_memory();
    
    // Tokenize prompt
    const int n_prompt = -llama_tokenize(g_vocab, prompt_text.c_str(), prompt_text.size(), NULL, 0, true, true);
    if (n_prompt <= 0) {
        throw_java_exception(env, "Prompt tokenization returned no tokens");
        return nullptr;
    }
    const int n_ctx = llama_n_ctx(g_context);
    if (n_prompt >= n_ctx - 8) {
        throw_java_exception(
            env,
            format_error("Prompt too long: tokens=%d context=%d", n_prompt, n_ctx)
        );
        return nullptr;
    }
    std::vector<llama_token> prompt_tokens(n_prompt);
    
    if (llama_tokenize(g_vocab, prompt_text.c_str(), prompt_text.size(), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        throw_java_exception(env, "Failed to tokenize prompt");
        return nullptr;
    }
    
    if (!decode_prompt_tokens(prompt_tokens)) {
        throw_java_exception(env, "Failed to decode prompt");
        return nullptr;
    }
    
    // Update sampler with new parameters
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    
    auto sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_sampler, llama_sampler_init_penalties(64, repeat_penalty, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(new_seed()));
    
    // Generate tokens
    std::string result;
    int n_generated = 0;
    int n_pos = prompt_tokens.size();
    const int effective_max_tokens = max_tokens > 0 ? max_tokens : n_ctx;
    
    g_should_stop = false;
    
    for (int i = 0; i < effective_max_tokens; i++) {
        if (g_should_stop) {
            LOGI("Generation stopped by user");
            break;
        }
        
        // Sample next token
        llama_token new_token = llama_sampler_sample(g_sampler, g_context, -1);
        llama_sampler_accept(g_sampler, new_token);
        
        // Check for EOS
        if (llama_vocab_is_eog(g_vocab, new_token)) {
            LOGI("EOS token reached");
            break;
        }
        
        if (n_pos >= n_ctx - 1) {
            LOGI("Context limit reached");
            break;
        }

        // Convert token to text
        std::string token_piece;
        if (!token_to_piece(new_token, token_piece)) {
            throw_java_exception(env, "Failed to convert generated token to text");
            return nullptr;
        }
        if (!token_piece.empty()) {
            result.append(token_piece);
        }
        
        // Prepare for next iteration
        llama_batch batch = llama_batch_get_one(&new_token, 1);
        n_pos++;
        
        if (llama_decode(g_context, batch) != 0) {
            throw_java_exception(env, "Failed to decode generated token");
            return nullptr;
        }
        
        n_generated++;
    }
    
    LOGI("Generated %d tokens", n_generated);
    
    // Create GenerationResult object
    jclass result_class = env->FindClass("net/nativemind/flutter_llama/FlutterLlamaPlugin$GenerationResult");
    if (!result_class) {
        throw_java_exception(env, "Failed to find GenerationResult class");
        return nullptr;
    }
    
    jmethodID constructor = env->GetMethodID(result_class, "<init>", "(Ljava/lang/String;I)V");
    if (!constructor) {
        throw_java_exception(env, "Failed to find GenerationResult constructor");
        return nullptr;
    }
    
    jstring j_result = safe_new_string_utf(env, result);
    jobject generation_result = env->NewObject(result_class, constructor, j_result, n_generated);
    
    return generation_result;
}

// Initialize streaming generation
JNIEXPORT jboolean JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeGenerateStreamInit(
    JNIEnv* env,
    jobject thiz,
    jstring prompt,
    jfloat temperature,
    jfloat top_p,
    jint top_k,
    jint max_tokens,
    jfloat repeat_penalty
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    LOGI("Initializing stream generation");
    
    if (!g_model || !g_context || !g_vocab) {
        g_stream_done = true;
        throw_java_exception(env, "Model not loaded");
        return JNI_FALSE;
    }
    
    g_should_stop = false;
    g_stream_n_pos = 0;
    g_stream_max_tokens = 0;
    g_stream_generated = 0;
    g_stream_done = false;
    
    const char* prompt_str = env->GetStringUTFChars(prompt, nullptr);
    if (!prompt_str) {
        g_stream_done = true;
        throw_java_exception(env, "Prompt string could not be read");
        return JNI_FALSE;
    }
    std::string prompt_text(prompt_str);
    env->ReleaseStringUTFChars(prompt, prompt_str);

    reset_context_memory();
    
    // Tokenize prompt
    const int n_prompt = -llama_tokenize(g_vocab, prompt_text.c_str(), prompt_text.size(), NULL, 0, true, true);
    if (n_prompt <= 0) {
        g_stream_done = true;
        throw_java_exception(env, "Prompt tokenization returned no tokens");
        return JNI_FALSE;
    }
    const int n_ctx = llama_n_ctx(g_context);
    if (n_prompt >= n_ctx - 8) {
        g_stream_done = true;
        throw_java_exception(
            env,
            format_error("Prompt too long: tokens=%d context=%d", n_prompt, n_ctx)
        );
        return JNI_FALSE;
    }
    std::vector<llama_token> prompt_tokens(n_prompt);
    
    if (llama_tokenize(g_vocab, prompt_text.c_str(), prompt_text.size(), prompt_tokens.data(), prompt_tokens.size(), true, true) < 0) {
        g_stream_done = true;
        throw_java_exception(env, "Failed to tokenize prompt");
        return JNI_FALSE;
    }
    
    if (!decode_prompt_tokens(prompt_tokens)) {
        g_stream_done = true;
        throw_java_exception(env, "Failed to decode prompt");
        return JNI_FALSE;
    }
    
    // Update sampler
    if (g_sampler) {
        llama_sampler_free(g_sampler);
    }
    
    auto sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);
    llama_sampler_chain_add(g_sampler, llama_sampler_init_penalties(64, repeat_penalty, 0.0f, 0.0f));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(top_p, 1));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(top_k));
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(new_seed()));
    
    g_stream_n_pos = static_cast<int>(prompt_tokens.size());
    g_stream_max_tokens = max_tokens > 0 ? max_tokens : n_ctx;
    g_stream_generated = 0;
    g_stream_done = false;

    LOGI("Stream generation initialized");
    return JNI_TRUE;
}

// Get next token in stream
JNIEXPORT jstring JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeGenerateStreamNext(
    JNIEnv* env,
    jobject thiz
) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_should_stop || g_stream_done || !g_context || !g_vocab || !g_sampler) {
        return nullptr;
    }

    const int n_ctx = llama_n_ctx(g_context);
    while (!g_should_stop && !g_stream_done && g_stream_generated < g_stream_max_tokens) {
        llama_token new_token = llama_sampler_sample(g_sampler, g_context, -1);
        llama_sampler_accept(g_sampler, new_token);

        if (llama_vocab_is_eog(g_vocab, new_token)) {
            g_stream_done = true;
            return nullptr;
        }

        if (g_stream_n_pos >= n_ctx - 1) {
            LOGI("Context limit reached");
            g_stream_done = true;
            return nullptr;
        }

        std::string token_piece;
        if (!token_to_piece(new_token, token_piece)) {
            g_stream_done = true;
            throw_java_exception(env, "Failed to convert generated token to text");
            return nullptr;
        }

        llama_batch batch = llama_batch_get_one(&new_token, 1);
        g_stream_n_pos++;
        g_stream_generated++;

        if (llama_decode(g_context, batch) != 0) {
            g_stream_done = true;
            throw_java_exception(env, "Failed to decode generated stream token");
            return nullptr;
        }

        if (!token_piece.empty()) {
            return safe_new_string_utf(env, token_piece);
        }
    }

    g_stream_done = true;
    return nullptr;
}

// End streaming generation
JNIEXPORT void JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeGenerateStreamEnd(
    JNIEnv* env,
    jobject thiz
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    LOGI("Ending stream generation");
    g_stream_n_pos = 0;
    g_stream_max_tokens = 0;
    g_stream_generated = 0;
    g_stream_done = true;
}

// Get model information
JNIEXPORT jobject JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeGetModelInfo(
    JNIEnv* env,
    jobject thiz
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    if (!g_model || !g_context) {
        return nullptr;
    }
    
    jlong n_params = llama_model_n_params(g_model);
    jint n_layers = llama_model_n_layer(g_model);
    jint context_size = llama_n_ctx(g_context);
    
    LOGI("Model info: params=%lld, layers=%d, context=%d", 
         (long long)n_params, n_layers, context_size);
    
    // Create ModelInfo object
    jclass info_class = env->FindClass("net/nativemind/flutter_llama/FlutterLlamaPlugin$ModelInfo");
    if (!info_class) {
        throw_java_exception(env, "Failed to find ModelInfo class");
        return nullptr;
    }
    
    jmethodID constructor = env->GetMethodID(info_class, "<init>", "(JII)V");
    if (!constructor) {
        throw_java_exception(env, "Failed to find ModelInfo constructor");
        return nullptr;
    }
    
    jobject model_info = env->NewObject(info_class, constructor, n_params, n_layers, context_size);
    return model_info;
}

// Free model
JNIEXPORT void JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeFreeModel(
    JNIEnv* env,
    jobject thiz
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    LOGI("Freeing model");
    
    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    
    if (g_context) {
        llama_free(g_context);
        g_context = nullptr;
    }
    
    if (g_model) {
        llama_free_model(g_model);
        g_model = nullptr;
    }
    
    g_vocab = nullptr;
    
    LOGI("Model freed successfully");
}

// Stop generation
JNIEXPORT void JNICALL
Java_net_nativemind_flutter_1llama_FlutterLlamaPlugin_nativeStopGeneration(
    JNIEnv* env,
    jobject thiz
) {
    std::lock_guard<std::mutex> lock(g_mutex);
    
    LOGI("Stopping generation");
    g_should_stop = true;
    g_stream_done = true;
}

} // extern "C"
