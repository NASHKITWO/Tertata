import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:catatan_uang/services/update_check.dart';

Map<String, Object?> release({String tag = 'v5.8.0', bool draft = false, bool pre = false, List<Map<String, Object?>>? assets}) => {
      'tag_name': tag,
      'html_url': 'https://github.com/NASHKITWO/Tertata/releases/tag/$tag',
      'draft': draft,
      'prerelease': pre,
      'body': 'Catatan rilis',
      'assets': assets ??
          [
            {'name': 'Tertata-v5.8.0.apk', 'browser_download_url': 'https://github.com/NASHKITWO/Tertata/releases/download/$tag/Tertata-v5.8.0.apk'},
            {'name': 'Tertata.apk', 'browser_download_url': 'https://github.com/NASHKITWO/Tertata/releases/download/$tag/Tertata.apk'},
            {'name': 'apk-sha256.txt', 'browser_download_url': 'https://github.com/NASHKITWO/Tertata/releases/download/$tag/apk-sha256.txt'},
          ],
    };

void main() {
  group('versi', () {
    test('membaca berbagai bentuk versi', () {
      expect(UpdateCheck.parseVersion('v5.7.3'), [5, 7, 3]);
      expect(UpdateCheck.parseVersion('5.7.3+8'), [5, 7, 3]);
      expect(UpdateCheck.parseVersion('abc'), isNull);
    });

    test('membandingkan angka, bukan teks', () {
      expect(UpdateCheck.compareVersions('5.10.0', '5.9.9'), greaterThan(0));
      expect(UpdateCheck.compareVersions('5.7.3', '5.7.3'), 0);
      expect(UpdateCheck.compareVersions('5.7.2', '5.7.3'), lessThan(0));
      expect(UpdateCheck.compareVersions('x', '5.7.3'), 0);
    });
  });

  group('parse rilis', () {
    test('versi lebih baru dikenali dan memilih Tertata.apk', () {
      final u = UpdateCheck.parse(release(), current: '5.7.3')!;
      expect(u.version, '5.8.0');
      expect(u.apkUrl, endsWith('/Tertata.apk'));
    });

    test('versi sama atau lebih lama diabaikan', () {
      expect(UpdateCheck.parse(release(tag: 'v5.7.3'), current: '5.7.3'), isNull);
      expect(UpdateCheck.parse(release(tag: 'v5.7.0'), current: '5.7.3'), isNull);
    });

    test('draft, prarilis, dan data rusak diabaikan', () {
      expect(UpdateCheck.parse(release(draft: true), current: '5.7.3'), isNull);
      expect(UpdateCheck.parse(release(pre: true), current: '5.7.3'), isNull);
      expect(UpdateCheck.parse('bukan json', current: '5.7.3'), isNull);
      expect(UpdateCheck.parse({'tag_name': 5}, current: '5.7.3'), isNull);
    });

    test('tautan di luar github.com ditolak', () {
      final j = release();
      j['html_url'] = 'https://evil.example/rilis';
      expect(UpdateCheck.parse(j, current: '5.7.3'), isNull);

      final k = release(assets: [
        {'name': 'x.apk', 'browser_download_url': 'https://evil.example/x.apk'},
      ]);
      expect(UpdateCheck.parse(k, current: '5.7.3')!.apkUrl, isNull);
    });
  });

  group('fetch', () {
    test('membaca jawaban 200', () async {
      final client = MockClient((_) async => http.Response(jsonEncode(release()), 200));
      final u = await UpdateCheck.fetch(client: client, current: '5.7.3');
      expect(u?.version, '5.8.0');
    });

    test('404 (belum ada rilis) berarti tidak ada pembaruan', () async {
      final client = MockClient((_) async => http.Response('{}', 404));
      expect(await UpdateCheck.fetch(client: client, current: '5.7.3'), isNull);
    });

    test('kode galat lain melempar', () async {
      final client = MockClient((_) async => http.Response('x', 500));
      expect(UpdateCheck.fetch(client: client, current: '5.7.3'), throwsException);
    });
  });
}
