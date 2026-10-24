#!/usr/bin/env python3
"""Menerapkan konfigurasi native (Android/iOS) yang dibutuhkan fitur Tertata.

Aman dijalankan berulang kali (idempotent). Pemakaian:
    python3 tool/setup_native.py [folder_proyek]
"""
import pathlib
import re
import shutil
import sys

PERMISSIONS = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.USE_BIOMETRIC',
    'android.permission.RECEIVE_BOOT_COMPLETED',
]

RECEIVERS = '''        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''

PLIST_KEYS = {
    'NSFaceIDUsageDescription': 'Untuk membuka aplikasi dengan Face ID',
    'NSCameraUsageDescription': 'Untuk memotret struk belanja',
    'NSPhotoLibraryUsageDescription': 'Untuk memilih foto struk',
}

DESUGAR = 'com.android.tools:desugar_jdk_libs:2.0.4'

# Layanan pembaca notifikasi bank/e-wallet dan widget layar utama (kode di tool/android/).
NATIVE_COMPONENTS = '''        <service android:name="%(pkg)s.TertataNotifListener" android:exported="true" android:label="Tertata" android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService"/>
            </intent-filter>
        </service>
        <receiver android:name="%(pkg)s.BalanceWidget" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/tertata_balance_widget_info"/>
        </receiver>
'''


def read(p):
    return p.read_text(encoding='utf-8')


def write(p, s):
    p.write_text(s, encoding='utf-8')


def patch_manifest(root, log):
    p = root / 'android/app/src/main/AndroidManifest.xml'
    if not p.exists():
        log.append('LEWATI  AndroidManifest.xml tidak ditemukan')
        return
    s = read(p)
    o = s
    add = ''.join('    <uses-permission android:name="%s"/>\n' % x for x in PERMISSIONS if x not in s)
    if add:
        s = re.sub(r'(<manifest[^>]*>[ \t]*\n)', lambda m: m.group(1) + add, s, count=1)
    if 'ScheduledNotificationReceiver' not in s:
        s = s.replace('</application>', RECEIVERS + '    </application>', 1)
    s = re.sub(r'(<application[^>]*?android:label=")[^"]*(")', r'\1Tertata\2', s, count=1)
    # Matikan auto-backup Android: kunci Keystore tidak ikut dipulihkan di HP baru, sehingga PIN
    # hasil pulihan tidak bisa diverifikasi (terkunci selamanya) dan data keuangan ikut tersalin ke cloud.
    if 'android:allowBackup' not in s:
        s = s.replace('<application', '<application android:allowBackup="false"', 1)
    if s != o:
        write(p, s)
        log.append('OK      AndroidManifest.xml diperbarui')
    else:
        log.append('SUDAH   AndroidManifest.xml')


def patch_main_activity(root, log):
    found = False
    for p in list((root / 'android/app/src/main').rglob('MainActivity.kt')) + list((root / 'android/app/src/main').rglob('MainActivity.java')):
        found = True
        s = read(p)
        n = re.sub(r'\bFlutterActivity\b', 'FlutterFragmentActivity', s)
        if n != s:
            write(p, n)
            log.append('OK      %s memakai FlutterFragmentActivity' % p.name)
        else:
            log.append('SUDAH   %s' % p.name)
    if not found:
        log.append('LEWATI  MainActivity tidak ditemukan')


def patch_android_native(root, log):
    """Memasang MainActivity (jembatan Flutter), pembaca notifikasi, widget, dan resource-nya."""
    main = root / 'android/app/src/main'
    acts = sorted(main.rglob('MainActivity.kt')) if main.exists() else []
    if not acts:
        log.append('LEWATI  MainActivity.kt tidak ditemukan (notifikasi otomatis & widget native dilewati)')
        return
    act = acts[0]
    m = re.search(r'^\s*package\s+([\w.]+)', read(act), re.M)
    if not m:
        log.append('LEWATI  paket MainActivity.kt tidak terbaca (notifikasi otomatis & widget native dilewati)')
        return
    pkg = m.group(1)
    here = pathlib.Path(__file__).resolve().parent / 'android'
    changed = 0
    for t in sorted((here / 'kotlin').glob('*.kt.tmpl')):
        dst = act.parent / t.name[:-len('.tmpl')]
        body = read(t).replace('__PACKAGE__', pkg)
        if not dst.exists() or read(dst) != body:
            write(dst, body)
            changed += 1
    for src in sorted((here / 'res').rglob('*')):
        if src.is_file():
            dst = main / 'res' / src.relative_to(here / 'res')
            dst.parent.mkdir(parents=True, exist_ok=True)
            body = read(src)
            if not dst.exists() or read(dst) != body:
                write(dst, body)
                changed += 1
    mf = main / 'AndroidManifest.xml'
    if mf.exists():
        s = read(mf)
        if 'TertataNotifListener' not in s:
            s = s.replace('</application>', NATIVE_COMPONENTS % {'pkg': pkg} + '    </application>', 1)
            write(mf, s)
            changed += 1
    log.append('OK      kode native (paket %s): %d berkas dipasang/diperbarui' % (pkg, changed) if changed
               else 'SUDAH   kode native (notifikasi otomatis & widget)')


def patch_gradle(root, log):
    kts = root / 'android/app/build.gradle.kts'
    groovy = root / 'android/app/build.gradle'
    if kts.exists():
        p, is_kts = kts, True
    elif groovy.exists():
        p, is_kts = groovy, False
    else:
        log.append('LEWATI  build.gradle aplikasi tidak ditemukan')
        return
    s = read(p)
    o = s

    # minSdk >= 23
    s = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', s)
    s = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23', s)
    s = re.sub(r'minSdk(Version)?(\s*=\s*|\s+)(\d+)',
               lambda m: m.group(0) if int(m.group(3)) >= 23 else 'minSdk%s%s23' % (m.group(1) or '', m.group(2)), s)

    # desugaring
    if 'oreLibraryDesugaringEnabled' not in s:
        line = '        isCoreLibraryDesugaringEnabled = true\n' if is_kts else '        coreLibraryDesugaringEnabled true\n'
        s, n = re.subn(r'(compileOptions\s*\{[ \t]*\n)', lambda m: m.group(1) + line, s, count=1)
        if n == 0:
            log.append('PERINGATAN compileOptions tidak ditemukan; aktifkan desugaring manual (lihat SETUP_NATIVE.md)')
    if 'coreLibraryDesugaring' not in re.sub(r'oreLibraryDesugaringEnabled', '', s):
        dep = ('    coreLibraryDesugaring("%s")\n' if is_kts else "    coreLibraryDesugaring '%s'\n") % DESUGAR
        if re.search(r'^dependencies\s*\{', s, re.M):
            s = re.sub(r'(^dependencies\s*\{[ \t]*\n)', lambda m: m.group(1) + dep, s, count=1, flags=re.M)
        else:
            s = s.rstrip('\n') + '\n\ndependencies {\n' + dep + '}\n'
    # Matikan R8/shrink pada build rilis: plugin berbasis JNI (mis. shared_preferences_android
    # versi baru) mencari method lewat nama, sehingga rusak jika namanya diacak/dihapus R8
    # ("NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll").
    if 'isMinifyEnabled' not in s and 'minifyEnabled' not in s:
        lines = ('            isMinifyEnabled = false\n            isShrinkResources = false\n' if is_kts
                 else '            minifyEnabled false\n            shrinkResources false\n')
        s, n = re.subn(r'(\brelease\s*\{[ \t]*\n)', lambda m: m.group(1) + lines, s, count=1)
        if n == 0:
            log.append('PERINGATAN blok release tidak ditemukan; matikan minify manual (lihat SETUP_NATIVE.md)')
    if s != o:
        write(p, s)
        log.append('OK      %s diperbarui (minSdk 23 + desugaring + tanpa R8)' % p.name)
    else:
        log.append('SUDAH   %s' % p.name)


def patch_signing(root, log):
    """Menghubungkan android/key.properties ke signingConfigs.release (kunci rilis tetap).

    Tanpa langkah ini Gradle tetap menandatangani APK rilis dengan kunci debug, walaupun
    key.properties sudah ditulis oleh CI. Jika key.properties tidak ada, build memakai kunci debug
    seperti biasa (cocok untuk pemakaian pribadi/uji). Idempotent.
    """
    kts = root / 'android/app/build.gradle.kts'
    groovy = root / 'android/app/build.gradle'
    if kts.exists():
        p, is_kts = kts, True
    elif groovy.exists():
        p, is_kts = groovy, False
    else:
        log.append('LEWATI  build.gradle aplikasi tidak ditemukan (penandatanganan rilis)')
        return
    s = read(p)
    if 'tertataKeyFile' in s:
        log.append('SUDAH   penandatanganan rilis di %s' % p.name)
        return
    o = s

    if is_kts:
        # Properties/FileInputStream lewat import dan di luar blok android { }: di dalam blok itu
        # `java` merujuk ke ekstensi Java Gradle sehingga `java.util`/`java.io` tidak terselesaikan.
        top = 'import java.io.FileInputStream\nimport java.util.Properties\n\n'
        pre = (
            'val tertataKeyProps = Properties()\n'
            'val tertataKeyFile = rootProject.file("key.properties")\n'
            'if (tertataKeyFile.exists()) {\n'
            '    FileInputStream(tertataKeyFile).use { tertataKeyProps.load(it) }\n'
            '}\n\n'
        )
        block = (
            '    signingConfigs {\n'
            '        if (tertataKeyFile.exists()) {\n'
            '            create("release") {\n'
            '                keyAlias = tertataKeyProps["keyAlias"] as String\n'
            '                keyPassword = tertataKeyProps["keyPassword"] as String\n'
            '                storeFile = rootProject.file(tertataKeyProps["storeFile"] as String)\n'
            '                storePassword = tertataKeyProps["storePassword"] as String\n'
            '            }\n'
            '        }\n'
            '    }\n'
        )
        use = 'signingConfig = if (tertataKeyFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
        dbg = re.compile(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)')
        s, n = re.subn(r'(^android\s*\{[ \t]*\n)', lambda m: pre + m.group(1) + block, s, count=1, flags=re.M)
        if n:
            s = top + s  # import wajib di paling atas berkas
    else:
        top = (
            'def tertataKeyProps = new Properties()\n'
            "def tertataKeyFile = rootProject.file('key.properties')\n"
            'if (tertataKeyFile.exists()) {\n'
            '    tertataKeyFile.withInputStream { tertataKeyProps.load(it) }\n'
            '}\n\n'
        )
        block = (
            '    signingConfigs {\n'
            '        release {\n'
            '            if (tertataKeyFile.exists()) {\n'
            "                keyAlias tertataKeyProps['keyAlias']\n"
            "                keyPassword tertataKeyProps['keyPassword']\n"
            "                storeFile rootProject.file(tertataKeyProps['storeFile'])\n"
            "                storePassword tertataKeyProps['storePassword']\n"
            '            }\n'
            '        }\n'
            '    }\n'
        )
        use = 'signingConfig tertataKeyFile.exists() ? signingConfigs.release : signingConfigs.debug'
        dbg = re.compile(r'signingConfig\s*=?\s*signingConfigs\.debug')
        s, n = re.subn(r'(^android\s*\{[ \t]*\n)', lambda m: top + m.group(1) + block, s, count=1, flags=re.M)
    if n == 0:
        log.append('PERINGATAN blok android { } tidak ditemukan; hubungkan key.properties manual (lihat README)')
        return

    # Pakai konfigurasi rilis di buildTypes.release.
    s, n = dbg.subn(use, s, count=1)
    if n == 0:
        s, n = re.subn(r'(buildTypes\s*\{[\s\S]*?\brelease\s*\{[ \t]*\n)', lambda m: m.group(1) + '            ' + use + '\n', s, count=1)
    if n == 0:
        log.append('PERINGATAN blok buildTypes.release tidak ditemukan; set signingConfig manual (lihat README)')
        return
    if s != o:
        write(p, s)
        log.append('OK      %s: signingConfigs.release membaca android/key.properties' % p.name)


def patch_plist(root, log):
    p = root / 'ios/Runner/Info.plist'
    if not p.exists():
        log.append('LEWATI  Info.plist tidak ditemukan')
        return
    s = read(p)
    o = s
    add = ''.join('\t<key>%s</key>\n\t<string>%s</string>\n' % (k, v) for k, v in PLIST_KEYS.items() if k not in s)
    if add:
        s = re.sub(r'(</dict>\s*</plist>)', lambda m: add + m.group(1), s, count=1)
    if s != o:
        write(p, s)
        log.append('OK      Info.plist diperbarui')
    else:
        log.append('SUDAH   Info.plist')


def patch_app_delegate(root, log):
    p = root / 'ios/Runner/AppDelegate.swift'
    if not p.exists():
        log.append('LEWATI  AppDelegate.swift tidak ditemukan')
        return
    s = read(p)
    if 'UNUserNotificationCenter' in s:
        log.append('SUDAH   AppDelegate.swift')
        return
    snippet = ('    if #available(iOS 10.0, *) {\n'
               '      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate\n'
               '    }\n')
    n, c = re.subn(r'(\n[ \t]*return super\.application\(application, didFinishLaunchingWithOptions: launchOptions\))',
                   lambda m: '\n' + snippet.rstrip('\n') + m.group(1), s, count=1)
    if c:
        write(p, n)
        log.append('OK      AppDelegate.swift diperbarui')
    else:
        log.append('PERINGATAN AppDelegate.swift berbeda dari template; pengingat di iOS mungkin perlu pengaturan manual')


def patch_icons(root, log):
    src = pathlib.Path(__file__).resolve().parent / 'icons'
    res = root / 'android/app/src/main/res'
    if not res.exists():
        log.append('LEWATI  folder res Android tidak ditemukan (ikon)')
        return
    n = 0
    for d in src.glob('mipmap-*'):
        dst = res / d.name
        dst.mkdir(parents=True, exist_ok=True)
        shutil.copy2(d / 'ic_launcher.png', dst / 'ic_launcher.png')
        n += 1
    log.append('OK      ikon Tertata dipasang (%d ukuran)' % n)


def main(root):
    root = pathlib.Path(root)
    log = []
    patch_manifest(root, log)
    patch_main_activity(root, log)
    patch_android_native(root, log)
    patch_gradle(root, log)
    patch_signing(root, log)
    patch_icons(root, log)
    patch_plist(root, log)
    patch_app_delegate(root, log)
    print('\n'.join(log))
    return log


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '.')
