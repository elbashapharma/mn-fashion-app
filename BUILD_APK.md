# بناء APK (M&N Fashion) — خطوات سهلة

> ملاحظة: ملف ZIP ده هو كود المشروع. لتثبيته على الموبايل لازم نحوله لملف APK.

## 1) على كمبيوتر (Windows / Mac / Linux)
### تثبيت Flutter
- نزّل Flutter (Stable) وثبته
- ثبّت Android Studio (عشان Android SDK)

## 2) تجهيز المشروع
1) فك الضغط في فولدر مثل: `mn_fashion_app`
2) افتح Terminal داخل الفولدر ونفّذ:
```bash
flutter create .
```
ده هيعمل ملفات Android/Gradle المطلوبة.

3) بعد كده نفّذ:
```bash
flutter pub get
```

## 3) تغيير اسم التطبيق على أندرويد (App Name)
بعد `flutter create .` افتح الملف:
`android/app/src/main/res/values/strings.xml`

وخلي:
```xml
<string name="app_name">M&N Fashion</string>
```

## 4) بناء APK (Release)
نفّذ:
```bash
flutter build apk --release
```

هتلاقي الـ APK هنا:
`build/app/outputs/flutter-apk/app-release.apk`

## 5) تثبيت على الموبايل
انقل `app-release.apk` للموبايل وثبّته.
قد تحتاج تفعيل: Install unknown apps.
