# التوزيع المباشر — SwiftCall

## رابط التحميل المباشر (GitHub Releases)

بعد كل push إلى main، يُنشأ Release تلقائياً على:
https://github.com/Abdjaradat/swiftcall/releases/latest

## كيف تشارك الرابط؟

### قناة تيليغرام (الأسرع)
1. أنشئ قناة تيليغرام باسم @SwiftCallApp
2. انشر رابط التحميل من GitHub Releases
3. اضغط "Pin Message" على رسالة الرابط

### بوابة بسيطة (HTML)
يمكن استخدام GitHub Pages مجاناً:
1. في GitHub: Settings → Pages → Source: main → /docs
2. أنشئ ملف docs/index.html (انظر أدناه)

```html
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <title>SwiftCall — تحميل</title>
  <style>
    body { font-family: Arial; text-align: center; padding: 50px; background: #0a0a1a; color: white; }
    .btn { background: #6C63FF; color: white; padding: 20px 40px; border-radius: 15px;
           text-decoration: none; font-size: 20px; display: inline-block; margin: 20px; }
  </style>
</head>
<body>
  <h1>📱 SwiftCall</h1>
  <p>مكالمات ودردشة بجودة عالية</p>
  <a class="btn" href="https://github.com/Abdjaradat/swiftcall/releases/latest/download/SwiftCall.apk">
    ⬇️ تحميل للأندرويد
  </a>
</body>
</html>
```

## Unity Ads — خطوات التفعيل الحقيقي

1. سجّل على: https://dashboard.unityads.unity.com
2. Create Project → اسم المشروع: SwiftCall
3. Monetization → Ad Units → Add Ad Unit:
   - Type: Rewarded Video
   - Platform: Android
4. احفظ الـ Game ID و Ad Unit ID
5. في `lib/data/services/ad_service.dart` استبدل:
   ```dart
   static const _androidGameId = 'YOUR_ANDROID_GAME_ID';
   static const _iosGameId     = 'YOUR_IOS_GAME_ID';
   String get _rewardedId => 'YOUR_AD_UNIT_ID';
   ```
6. غيّر `testMode: true` إلى `testMode: false`
7. ادفع التغييرات لـ GitHub

## نصيحة للربح

- Rewarded Ad (50 توكن) = المستخدم يشاهد 30 ثانية
- السعر التقديري لكل 1000 مشاهدة (eCPM):
  - المنطقة العربية: $2–$8
  - إذا 1000 مستخدم × 3 إعلانات/يوم = ~$6–24/يوم
