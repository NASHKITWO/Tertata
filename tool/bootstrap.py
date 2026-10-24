#!/usr/bin/env python3
"""Menyiapkan proyek Flutter lengkap dari folder ini (membuat android/ & ios/, menerapkan
konfigurasi native, mengunduh paket). Tambahkan --build untuk sekaligus membuat APK rilis.

    python3 tool/bootstrap.py            # siapkan saja
    python3 tool/bootstrap.py --build    # siapkan + build APK
"""
import argparse
import pathlib
import subprocess
import sys

ap = argparse.ArgumentParser()
ap.add_argument('--build', action='store_true', help='build APK rilis setelah persiapan')
ap.add_argument('--flutter', default='flutter', help='perintah/jalur flutter')
args = ap.parse_args()

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / 'tool'))
import setup_native  # noqa: E402


def run(cmd):
    print('$', ' '.join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=root, shell=(sys.platform == 'win32'))
    if r.returncode != 0:
        sys.exit(r.returncode)


if not ((root / 'android/app/build.gradle.kts').exists() or (root / 'android/app/build.gradle').exists()):
    run([args.flutter, 'create', '.', '--org', 'id.catatanuang', '--project-name', 'catatan_uang', '--platforms=android,ios'])

# 'flutter create' membuat tes contoh (aplikasi counter) yang tidak cocok dengan aplikasi ini.
sample = root / 'test' / 'widget_test.dart'
if sample.exists() and 'MyApp' in sample.read_text(encoding='utf-8'):
    sample.unlink()
    print('Menghapus test/widget_test.dart contoh bawaan Flutter')

setup_native.main(root)
run([args.flutter, 'pub', 'get'])
if args.build:
    run([args.flutter, 'build', 'apk', '--release'])
    print('\nAPK: build/app/outputs/flutter-apk/app-release.apk')
