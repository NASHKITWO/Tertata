import 'package:flutter_test/flutter_test.dart';
import 'package:catatan_uang/services/ai.dart';

void main() {
  test('alamat API: https boleh, http publik ditolak, http jaringan lokal boleh', () {
    expect(AiService.checkBaseUrl('https://api.groq.com/openai/v1'), isNull);
    expect(AiService.checkBaseUrl('http://api.contoh.com/v1'), isNotNull);
    expect(AiService.checkBaseUrl('http://8.8.8.8/v1'), isNotNull);
    expect(AiService.checkBaseUrl('http://localhost:11434/v1'), isNull);
    expect(AiService.checkBaseUrl('http://192.168.1.20:11434/v1'), isNull);
    expect(AiService.checkBaseUrl('http://172.20.0.5/v1'), isNull);
    expect(AiService.checkBaseUrl('http://172.40.0.5/v1'), isNotNull);
    expect(AiService.checkBaseUrl('ftp://x.com'), isNotNull);
    expect(AiService.checkBaseUrl('bukan url'), isNotNull);
    expect(AiService.checkBaseUrl(''), isNotNull);
  });
}
