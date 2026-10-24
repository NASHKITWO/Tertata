# Pengaturan native (sekali saja, setelah `flutter create`)

> Semua langkah di bawah dijalankan otomatis oleh `python3 tool/bootstrap.py` (atau `python3 tool/setup_native.py`).
> Panduan ini hanya untuk referensi atau jika Anda ingin melakukannya manual.

Fitur baru (biometrik, pengingat, scan struk) butuh sedikit konfigurasi platform.
Tanpa langkah ini aplikasi tetap bisa dikompilasi di sebagian besar kasus, tetapi fitur terkait tidak akan berfungsi.

## Android

### 1. `android/app/src/main/AndroidManifest.xml`
Di dalam `<manifest>` (di atas `<application>`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```
Di dalam `<application>` (di bawah `<activity>`):
```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

### 2. `MainActivity` (wajib untuk biometrik)
`android/app/src/main/kotlin/<paket-anda>/MainActivity.kt`:
```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

### 3. `android/app/build.gradle.kts` (atau `build.gradle`)
```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    defaultConfig { minSdk = 23 }
    buildTypes {
        release {
            isMinifyEnabled = false   // wajib: R8 merusak plugin berbasis JNI
            isShrinkResources = false
        }
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
```
Versi Groovy: `minifyEnabled false`, `shrinkResources false`, `coreLibraryDesugaringEnabled true` dan `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`.

## iOS
`ios/Runner/Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key><string>Untuk membuka aplikasi dengan Face ID</string>
<key>NSCameraUsageDescription</key><string>Untuk memotret struk belanja</string>
<key>NSPhotoLibraryUsageDescription</key><string>Untuk memilih foto struk</string>
```
`ios/Runner/AppDelegate.swift`, di dalam `didFinishLaunchingWithOptions` sebelum `return`:
```swift
if #available(iOS 10.0, *) {
  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
}
```


## Notifikasi otomatis & widget layar utama (Android)
Dipasang otomatis oleh `tool/setup_native.py` dari folder `tool/android/` (berkas `*.kt.tmpl` disalin ke
`android/app/src/main/kotlin/<paket>/` dengan `__PACKAGE__` diganti paket aplikasi; layout, drawable, dan XML widget
disalin ke `res/`). Skrip juga menambahkan ke `AndroidManifest.xml`:
```xml
<service android:name="<paket>.TertataNotifListener" android:exported="true" android:label="Tertata"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
  <intent-filter><action android:name="android.service.notification.NotificationListenerService"/></intent-filter>
</service>
<receiver android:name="<paket>.BalanceWidget" android:exported="false">
  <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE"/></intent-filter>
  <meta-data android:name="android.appwidget.provider" android:resource="@xml/tertata_balance_widget_info"/>
</receiver>
```
`MainActivity.kt` diganti dengan versi dari template (tetap `FlutterFragmentActivity`) yang memuat `MethodChannel("tertata/native")`.
Daftar aplikasi bank/e-wallet yang dibaca ada di `NotifInbox.kt` (`APP_PACKAGES`); tambahkan paket aplikasi Anda bila belum ada
(cek nama paket di Info aplikasi, atau `adb shell pm list packages | grep <nama>`).

Catatan Android 13+: untuk APK yang dipasang manual (bukan dari Play Store), sistem memblokir akses notifikasi lewat "pengaturan terbatas".
Buka Info aplikasi Tertata > menu titik tiga > **Izinkan pengaturan terbatas**, lalu aktifkan akses notifikasi.
Penerbitan di Google Play untuk izin pembaca notifikasi memerlukan formulir deklarasi tersendiri.
