/// Penyedia AI dengan API kompatibel OpenAI (POST {baseUrl}/chat/completions).
class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.tagline,
    required this.baseUrl,
    required this.models,
    required this.keyUrl,
    required this.keyHint,
    required this.vision,
  });
  final String id;
  final String name;
  final String tagline;
  final String baseUrl; // kosong = diisi pengguna (custom)
  final Map<String, String> models; // id model -> keterangan
  final String keyUrl;
  final String keyHint;
  final bool vision; // mendukung foto (scan struk)
  String get defaultModel => models.isEmpty ? '' : models.keys.first;
  bool get custom => baseUrl.isEmpty;
}

const kAiProviders = <AiProvider>[
  AiProvider(
    id: 'gemini',
    name: 'Google Gemini',
    tagline: 'Gratis · paling direkomendasikan · bisa scan struk',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    models: {
      'gemini-3.8-flash': 'Gemini 3.8 Flash · cerdas & cepat',
      'gemini-3.5-flash-lite': 'Gemini 3.5 Flash-Lite · hemat kuota',
      'gemini-3.6-flash': 'Gemini 3.6 Flash',
    },
    keyUrl: 'aistudio.google.com/apikey',
    keyHint: 'AIza…',
    vision: true,
  ),
  AiProvider(
    id: 'groq',
    name: 'Groq',
    tagline: 'Gratis · sangat cepat · hanya teks',
    baseUrl: 'https://api.groq.com/openai/v1',
    models: {
      'llama-3.3-70b-versatile': 'Llama 3.3 70B · seimbang',
      'openai/gpt-oss-120b': 'GPT-OSS 120B · lebih cerdas',
      'llama-3.1-8b-instant': 'Llama 3.1 8B · paling cepat',
    },
    keyUrl: 'console.groq.com/keys',
    keyHint: 'gsk_…',
    vision: false,
  ),
  AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    tagline: 'Banyak model berlabel :free · kuota harian kecil',
    baseUrl: 'https://openrouter.ai/api/v1',
    models: {
      'google/gemma-4-31b-it:free': 'Gemma 4 31B (gratis)',
      'google/gemma-4-26b-a4b-it:free': 'Gemma 4 26B (gratis)',
      'nvidia/nemotron-3.5-super-vl:free': 'Nemotron 3.5 Super VL (gratis, bisa foto)',
    },
    keyUrl: 'openrouter.ai/keys',
    keyHint: 'sk-or-…',
    vision: true,
  ),
  AiProvider(
    id: 'custom',
    name: 'Lainnya',
    tagline: 'Layanan apa pun yang kompatibel OpenAI (OpenAI, Mistral, Ollama, dll.)',
    baseUrl: '',
    models: {},
    keyUrl: '',
    keyHint: 'kunci API',
    vision: true,
  ),
];

AiProvider aiProviderById(String id) => kAiProviders.firstWhere((p) => p.id == id, orElse: () => kAiProviders.first);
