# تقرير حالة الأجهزة - SwiftCall
**تاريخ الفحص**: 2026-06-01 16:27

---

## 📱 الأجهزة المستخدمة

### الجهاز الفعلي: CRT NX1
- **Device ID**: AYAV6R3616014944
- **Android**: 15 (API 35)
- **الحالة**: ✅ متصل وجاهز
- **التطبيق**: مثبت ويعمل

### المحاكي: Pixel 6 API 33
- **Device ID**: emulator-5554
- **Android**: 13 (API 33)
- **الحالة**: ✅ متصل وجاهز
- **التطبيق**: مثبت ويعمل

---

## ✅ ما يعمل بشكل صحيح

### الأذونات الممنوحة على كلا الجهازين:
- ✅ `POST_NOTIFICATIONS` - للإشعارات
- ✅ `USE_FULL_SCREEN_INTENT` - لإشعارات المكالمات بملء الشاشة
- ✅ `FOREGROUND_SERVICE` - لخدمات المقدمة
- ✅ `MANAGE_OWN_CALLS` - لإدارة المكالمات
- ✅ `MODIFY_AUDIO_SETTINGS` - لإعدادات الصوت
- ✅ `WAKE_LOCK` - لإبقاء الجهاز مستيقظ
- ✅ `VIBRATE` - للاهتزاز
- ✅ `RECEIVE_BOOT_COMPLETED` - لبدء التطبيق عند التشغيل

### الخدمات النشطة:
- ✅ `MessageListenerService` - تعمل على كلا الجهازين
- ✅ `SwiftCallFirebaseMessagingService` - تعمل على كلا الجهازين
- ✅ Firebase Cloud Messaging متصل

### التطبيق:
- ✅ يفتح بدون أخطاء
- ✅ MainActivity نشطة وتعمل
- ✅ اللوقات نظيفة من أخطاء التطبيق

---

## ⚠️ المشاكل المكتشفة

### 1. 🔴 Firestore Index مفقود (CRITICAL)

**المشكلة**: 
استعلام الرسائات غير المقروءة يحتاج إلى Composite Index في Firestore

**الاستعلام الذي يفشل**:
```
Query(chats/{chatId}/messages 
  where isRead == false 
  and senderId != {currentUserId} 
  order by senderId, __name__)
```

**الحقول المطلوبة للـ Index**:
1. `isRead` (Ascending)
2. `senderId` (Ascending)
3. `__name__` (Ascending)

**الحل**:
افتح الرابط التالي لإنشاء الـ Index تلقائيًا:
```
https://console.firebase.google.com/v1/r/project/swiftcall-eec90/firestore/indexes?create_composite=ClBwcm9qZWN0cy9zd2lmdGNhbGwtZWVjOTAvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2luZGV4ZXMvXxABGgoKBmlzUmVhZBABGgwKCHNlbmRlcklkEAEaDAoIX19uYW1lX18QAQ
```

**الأثر**:
- ❌ عدد الرسائل غير المقروءة لن يظهر
- ❌ علامات "جديد" على المحادثات لن تعمل
- ✅ المكالمات ستعمل بشكل طبيعي (لا تحتاج هذا الـ index)

---

### 2. 🟡 Firebase App Check غير مفعل (LOW PRIORITY)

**المشكلة**:
```
Error getting App Check token; using placeholder token instead
```

**الحل**: 
تفعيل Firebase App Check في Firebase Console (اختياري للتطوير)

**الأثر**:
- لا يؤثر على عمل التطبيق في بيئة التطوير
- يُنصح بتفعيله في الإنتاج للأمان

---

### 3. 🟡 أذونات Foreground Service على المحاكي (INFO)

**المشكلة**:
المحاكي API 33 لا يطلب أذونات:
- `FOREGROUND_SERVICE_CAMERA`
- `FOREGROUND_SERVICE_MICROPHONE`  
- `FOREGROUND_SERVICE_PHONE_CALL`

**الحل**: 
هذه الأذونات مطلوبة في Android 14+ فقط، والمحاكي على API 33

**الأثر**:
- ✅ لا يؤثر على المحاكي الحالي
- ⚠️ الجهاز الفعلي (Android 15) يحتاجها وهي ممنوحة بالفعل

---

## 📊 أخطاء Android النظامية (يمكن تجاهلها)

هذه أخطاء من نظام Android وخدمات Google وليست من التطبيق:
- ❌ NfcAdapter is null
- ❌ BadAuthentication (Google Auth)
- ❌ TrichromeLibrary not found
- ❌ VoiceMail service errors
- ❌ Google Calendar sync errors

**لا تحتاج إصلاح** - هذه أخطاء طبيعية في المحاكيات.

---

## 🧪 التوصيات للاختبار

### الخيار 1: إصلاح الـ Index أولاً (موصى به)
1. افتح رابط Firebase لإنشاء الـ index
2. انتظر 1-2 دقيقة لبناء الـ index
3. أعد تشغيل التطبيق
4. ابدأ الاختبار الكامل

### الخيار 2: اختبار المكالمات فقط (سريع)
- المكالمات لا تحتاج الـ index المفقود
- يمكن اختبارها مباشرة
- لكن عداد الرسائل غير المقروءة لن يعمل

### الخيار 3: تعطيل استعلام الرسائل غير المقروءة مؤقتًا
- تعليق الكود الذي يستخدم هذا الاستعلام
- اختبار كل شيء
- إعادة تفعيله بعد إنشاء الـ index

---

## 🎯 الخطوات التالية

### لاختبار المكالمات:
1. ✅ الأجهزة جاهزة
2. ⏳ سجل دخول بحسابين مختلفين على الجهازين
3. ⏳ ابدأ مكالمة من جهاز للآخر
4. ⏳ راقب النتائج في اللوقات

### لإصلاح مشكلة الـ Index:
1. افتح Firebase Console
2. انقر على الرابط المقدم أعلاه
3. اضغط "Create Index"
4. انتظر اكتمال البناء

---

## 📝 ملاحظات إضافية

- اللوقات يتم مراقبتها تلقائيًا على كلا الجهازين
- أي خطأ من SwiftCall سيظهر فورًا
- الأخطاء الحالية كلها من نظام Android
- التطبيق جاهز للاختبار اليدوي
