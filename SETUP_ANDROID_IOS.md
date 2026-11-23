# Configuração nativa (fazer uma vez)

## 1. pubspec.yaml (em dependencies)
    local_auth: ^2.3.0
    flutter_secure_storage: ^9.2.2

Depois: flutter pub get

## 2. Android
Arquivo: android/app/src/main/kotlin/com/example/s3_bank_flutter/MainActivity.kt

    package com.example.s3_bank_flutter

    import io.flutter.embedding.android.FlutterFragmentActivity

    class MainActivity : FlutterFragmentActivity()

(local_auth exige FlutterFragmentActivity, não FlutterActivity.)

Arquivo: android/app/src/main/AndroidManifest.xml, dentro de <manifest>, antes de <application>:

    <uses-permission android:name="android.permission.USE_BIOMETRIC" />

minSdk: local_auth exige Android 6.0 (API 23) ou superior. Confira em android/app/build.gradle.kts.

## 3. iOS
O projeto não tem a pasta ios/. Para gerar: flutter create --platforms=ios .
Depois, em ios/Runner/Info.plist:

    <key>NSFaceIDUsageDescription</key>
    <string>Usamos o Face ID para proteger sua conta e confirmar transações.</string>

## 4. Rodar os testes
    flutter test test/security
