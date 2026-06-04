import '../../domain/entities/ai_model.dart';

/// All download URLs point to public HuggingFace GGUF repos.
/// Format: https://huggingface.co/<owner>/<repo>/resolve/main/<filename>
/// The Dio download service follows the CDN redirect automatically.
///
/// Recommended starter model for testing: SmolLM2 1.7B (1 GB, fast on CPU).
class MockModelData {
  static List<AiModel> getBrowsableModels() {
    return [
      // ── SmolLM2 1.7B ── best for first test (tiny, fast) ─────────────────
      AiModel(
        id: 'smollm2-1.7b-instruct',
        name: 'SmolLM2 1.7B Instruct',
        provider: 'HuggingFace',
        description:
            'Ultra-compact model designed for on-device deployment with minimal memory. Best choice for first-time testing.',
        sizeGb: 1.03,
        downloadUrl:
            'https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF'
            '/resolve/main/smollm2-1.7b-instruct-q4_k_m.gguf',
        category: ModelCategory.chat,
        version: '2.0',
        releaseDate: DateTime(2024, 11, 5),
        parameterCount: 17,
        providerIcon: '🤗',
        contextLength: 8192,
        tags: ['ultra-compact', 'on-device', 'fast', 'recommended'],
      ),

      // ── Phi-3.5 Mini 3.8B ─────────────────────────────────────────────────
      AiModel(
        id: 'phi-3.5-mini-instruct',
        name: 'Phi-3.5 Mini Instruct',
        provider: 'Microsoft',
        description:
            'Microsoft\'s 3.8B model optimised for speed and efficiency. Excellent reasoning in a small package.',
        sizeGb: 2.37,
        downloadUrl:
            'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF'
            '/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '3.5',
        releaseDate: DateTime(2024, 8, 20),
        parameterCount: 38,
        providerIcon: '🪟',
        contextLength: 131072,
        tags: ['fast', 'efficient', 'mobile'],
      ),

      // ── Gemma 3 4B ────────────────────────────────────────────────────────
      AiModel(
        id: 'gemma-3-4b-instruct',
        name: 'Gemma 3 4B Instruct',
        provider: 'Google',
        description:
            'Lightweight multilingual model with strong reasoning and instruction-following capabilities.',
        sizeGb: 2.51,
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-3-4b-it-GGUF'
            '/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '3.0',
        releaseDate: DateTime(2025, 3, 12),
        parameterCount: 40,
        providerIcon: '🔷',
        contextLength: 8192,
        tags: ['multilingual', 'instruct', 'lightweight'],
      ),

      // ── Phi-4 Mini 3.8B ───────────────────────────────────────────────────
      AiModel(
        id: 'phi-4-mini-instruct',
        name: 'Phi-4 Mini Instruct',
        provider: 'Microsoft',
        description:
            'Microsoft\'s compact powerhouse with exceptional math and science capabilities.',
        sizeGb: 2.49,
        downloadUrl:
            'https://huggingface.co/bartowski/Phi-4-mini-instruct-GGUF'
            '/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf',
        category: ModelCategory.reasoning,
        version: '4.0-mini',
        releaseDate: DateTime(2025, 2, 5),
        parameterCount: 38,
        providerIcon: '🪟',
        contextLength: 16384,
        tags: ['math', 'science', 'compact'],
      ),

      // ── Llama 3.2 3B ──────────────────────────────────────────────────────
      AiModel(
        id: 'llama-3.2-3b-instruct',
        name: 'Llama 3.2 3B Instruct',
        provider: 'Meta',
        description:
            'Meta\'s small but capable instruction-tuned model, ideal for edge devices.',
        sizeGb: 2.02,
        downloadUrl:
            'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF'
            '/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '3.2',
        releaseDate: DateTime(2024, 9, 25),
        parameterCount: 30,
        providerIcon: '🦙',
        contextLength: 131072,
        tags: ['edge', 'instruct', 'fast'],
      ),

      // ── Qwen2.5 7B ────────────────────────────────────────────────────────
      AiModel(
        id: 'qwen2.5-7b-instruct',
        name: 'Qwen2.5 7B Instruct',
        provider: 'Alibaba',
        description:
            'Alibaba\'s high-performance instruction model with excellent multilingual support.',
        sizeGb: 4.68,
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF'
            '/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf',
        category: ModelCategory.instruct,
        version: '2.5',
        releaseDate: DateTime(2024, 9, 18),
        parameterCount: 70,
        providerIcon: '🌐',
        contextLength: 131072,
        tags: ['multilingual', 'coding', 'math'],
      ),

      // ── Qwen2.5 Coder 7B ──────────────────────────────────────────────────
      AiModel(
        id: 'qwen2.5-coder-7b',
        name: 'Qwen2.5 Coder 7B',
        provider: 'Alibaba',
        description:
            'Specialised coding model with support for 40+ programming languages.',
        sizeGb: 4.68,
        downloadUrl:
            'https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF'
            '/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf',
        category: ModelCategory.coding,
        version: '2.5',
        releaseDate: DateTime(2024, 11, 12),
        parameterCount: 70,
        providerIcon: '🌐',
        contextLength: 131072,
        tags: ['coding', 'completion', 'debug'],
      ),

      // ── Llama 3.1 8B ──────────────────────────────────────────────────────
      AiModel(
        id: 'llama-3.1-8b-instruct',
        name: 'Llama 3.1 8B Instruct',
        provider: 'Meta',
        description:
            'Balanced model with strong general performance across tasks.',
        sizeGb: 4.92,
        downloadUrl:
            'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF'
            '/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '3.1',
        releaseDate: DateTime(2024, 7, 23),
        parameterCount: 80,
        providerIcon: '🦙',
        contextLength: 131072,
        tags: ['general', 'instruct', 'balanced'],
      ),

      // ── Mistral 7B ────────────────────────────────────────────────────────
      AiModel(
        id: 'mistral-7b-instruct-v0.3',
        name: 'Mistral 7B Instruct v0.3',
        provider: 'Mistral AI',
        description:
            'Mistral\'s flagship 7B model with function calling and sliding window attention.',
        sizeGb: 4.37,
        downloadUrl:
            'https://huggingface.co/MaziyarPanahi/Mistral-7B-Instruct-v0.3-GGUF'
            '/resolve/main/Mistral-7B-Instruct-v0.3.Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '0.3',
        releaseDate: DateTime(2024, 5, 22),
        parameterCount: 70,
        providerIcon: '💨',
        contextLength: 32768,
        tags: ['function-calling', 'general', 'efficient'],
      ),

      // ── DeepSeek R1 7B ────────────────────────────────────────────────────
      AiModel(
        id: 'deepseek-r1-7b',
        name: 'DeepSeek R1 7B',
        provider: 'DeepSeek',
        description:
            'Open-source reasoning model with chain-of-thought capabilities comparable to o1.',
        sizeGb: 4.68,
        downloadUrl:
            'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF'
            '/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
        category: ModelCategory.reasoning,
        version: 'R1',
        releaseDate: DateTime(2025, 1, 20),
        parameterCount: 70,
        providerIcon: '🌊',
        contextLength: 131072,
        tags: ['reasoning', 'chain-of-thought', 'math'],
      ),

      // ── Gemma 3 12B ───────────────────────────────────────────────────────
      AiModel(
        id: 'gemma-3-12b-instruct',
        name: 'Gemma 3 12B Instruct',
        provider: 'Google',
        description:
            'Mid-size Google model with excellent coding and long-context reasoning.',
        sizeGb: 7.34,
        downloadUrl:
            'https://huggingface.co/bartowski/gemma-3-12b-it-GGUF'
            '/resolve/main/gemma-3-12b-it-Q4_K_M.gguf',
        category: ModelCategory.instruct,
        version: '3.0',
        releaseDate: DateTime(2025, 3, 12),
        parameterCount: 120,
        providerIcon: '🔷',
        contextLength: 131072,
        tags: ['coding', 'reasoning', 'long-context'],
      ),

      // ── Nemotron Mini 4B ──────────────────────────────────────────────────
      AiModel(
        id: 'nemotron-mini-4b',
        name: 'Nemotron Mini 4B',
        provider: 'NVIDIA',
        description:
            'Hybrid reasoning model by NVIDIA, excelling at complex analytical tasks.',
        sizeGb: 2.84,
        downloadUrl:
            'https://huggingface.co/bartowski/Nemotron-Mini-4B-Instruct-GGUF'
            '/resolve/main/Nemotron-Mini-4B-Instruct-Q4_K_M.gguf',
        category: ModelCategory.reasoning,
        version: '3.0-nano',
        releaseDate: DateTime(2024, 10, 15),
        parameterCount: 40,
        providerIcon: '⚡',
        contextLength: 4096,
        tags: ['reasoning', 'hybrid', 'nvidia'],
      ),
    ];
  }
}
