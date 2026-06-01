# Unity Ads Setup - SwiftCall

## 📋 الوضع الحالي

### ⚠️ المشكلة: الإعلانات لا تظهر

**السبب المحتمل:**
1. Game ID قد لا يكون صحيح أو غير مفعّل في Unity Dashboard
2. الـ Placements غير موجودة في Unity Dashboard
3. التطبيق غير معتمد في Unity Ads
4. لا توجد إعلانات متاحة في Production Mode

---

## 🔧 الإعدادات الحالية في الكود

```dart
Game ID (Android): 800000852
Game ID (iOS): 800000852
Test Mode: true ⚠️ (مفعّل للاختبار)

Placements:
- Rewarded: Rewarded_Android
- Interstitial: Interstitial_Android
- Banner: Banner_Android
```

**الملف**: `lib/data/services/ad_service.dart`

---

## ✅ خطوات التحقق من Unity Dashboard

### 1. تسجيل الدخول إلى Unity Dashboard
```
https://dashboard.unity3d.com/
```
- الحساب: `jaradatabdullah122@gmail.com`

### 2. التحقق من Project
- اذهب إلى: **Monetization** → **Projects**
- تأكد أن المشروع موجود
- تأكد أن Game ID هو: `800000852`

### 3. التحقق من Ad Placements
اذهب إلى: **Ad placements**

تأكد من وجود:
- ✅ **Rewarded_Android** (نوع: Rewarded)
- ✅ **Interstitial_Android** (نوع: Interstitial)
- ✅ **Banner_Android** (نوع: Banner)

إذا لم تكن موجودة، أنشئها:
1. اضغط **Add ad placement**
2. اسم: `Rewarded_Android`
3. النوع: **Rewarded video**
4. المنصة: **Android**
5. اضغط **Save**

كرر نفس الخطوات لـ Interstitial و Banner

### 4. التحقق من حالة التطبيق
- اذهب إلى: **App settings**
- تأكد أن:
  - ✅ **Status**: Active
  - ✅ **Ad serving**: Enabled
  - ✅ **Platform**: Android مفعّل

### 5. معلومات التطبيق
تأكد من:
- **Package name**: `com.swiftcall.app`
- **Store listing**: (رابط Google Play إذا كان منشور)

---

## 🧪 اختبار الإعلانات

### Test Mode (مفعّل حالياً)
```dart
testMode: true
```

**الميزات:**
- ✅ إعلانات تجريبية تظهر دائماً
- ✅ لا تحتاج موافقة من Unity
- ✅ تعمل فوراً بدون انتظار

**للاختبار:**
1. ثبّت التطبيق
2. اذهب إلى شاشة المحفظة
3. اضغط "شاهد إعلان واحصل على توكنز"
4. يجب أن تظهر إعلان تجريبي

### Production Mode
```dart
testMode: false
```

**المتطلبات:**
- ✅ Game ID صحيح ومفعّل
- ✅ Placements موجودة
- ✅ التطبيق معتمد في Unity Dashboard
- ✅ إعلانات حقيقية متاحة

---

## 🔍 فحص اللوقات

بعد تشغيل التطبيق، افحص اللوقات:

```bash
adb logcat | grep -i unity
```

**اللوقات المتوقعة:**
```
✅ Unity Ads initialized successfully! GameID: 800000852
🔄 Loading Rewarded Ad: Rewarded_Android
✅ Rewarded Ad loaded: Rewarded_Android
🔄 Loading Interstitial Ad: Interstitial_Android
✅ Interstitial Ad loaded: Interstitial_Android
```

**إذا ظهرت أخطاء:**
```
❌ Unity Ads initialization failed: INVALID_ARGUMENT - Invalid Game ID
❌ Rewarded Ad load failed: Rewarded_Android - NO_FILL - No ads available
```

---

## 🛠️ الحلول للمشاكل الشائعة

### Problem 1: Invalid Game ID
**الحل:**
1. تحقق من Game ID في Unity Dashboard
2. انسخه بالضبط
3. غيره في `ad_service.dart` السطر 13-14

### Problem 2: Placement not found
**الحل:**
1. أنشئ الـ Placements في Unity Dashboard
2. تأكد أن الأسماء متطابقة بالضبط:
   - `Rewarded_Android` (حساس لحالة الأحرف!)
   - `Interstitial_Android`
   - `Banner_Android`

### Problem 3: No Fill (No ads available)
**السبب:** Unity ما عنده إعلانات متاحة لبلدك/جهازك

**الحل:**
- استخدم Test Mode أولاً
- تأكد أن Unity Ads مفعّل في Dashboard
- انتظر 24-48 ساعة بعد تفعيل الحساب

### Problem 4: App not approved
**الحل:**
1. اذهب إلى Unity Dashboard
2. **Monetization** → **Ad placements**
3. تأكد أن Status = **Active**
4. إذا كان **Pending**, انتظر الموافقة (1-3 أيام)

---

## 📝 خطوات التفعيل النهائي

### للنشر في Production:

1. ✅ تأكد أن Test Mode يعمل
2. ✅ تأكد من جميع الإعدادات في Unity Dashboard
3. ✅ غيّر `testMode: true` إلى `testMode: false`
4. ✅ احذف الـ print statements (أو خليها للـ debugging)
5. ✅ ابني APK جديد
6. ✅ ثبّت واختبر

---

## 📞 معلومات الدعم

**Unity Dashboard:**
```
https://dashboard.unity3d.com/
```

**Unity Ads Documentation:**
```
https://docs.unity.com/ads/
```

**Unity Support:**
```
https://support.unity.com/
```

---

## ✅ Checklist للتحقق

قبل النشر، تأكد من:
- [ ] Game ID صحيح في الكود
- [ ] Game ID نفسه موجود في Unity Dashboard
- [ ] الثلاثة Placements موجودة (Rewarded, Interstitial, Banner)
- [ ] أسماء Placements متطابقة بالضبط
- [ ] Package name صحيح: `com.swiftcall.app`
- [ ] Test Mode يعمل ويظهر إعلانات تجريبية
- [ ] Unity Ads status = Active في Dashboard
- [ ] قرأت اللوقات ولا يوجد أخطاء

---

**آخر تحديث**: 2026-06-01
**النسخة**: 1.0.13+14 (Test Mode)
