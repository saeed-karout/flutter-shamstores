# 🚗 Sham Stores - تطبيق مندوب التوصيل

تطبيق Flutter مخصص لمندوبي التوصيل في منصة شام ستور.

## المميزات

- ✅ تسجيل الدخول بأمان (JWT)
- ✅ استقبال وإدارة طلبات التوصيل في الوقت الفعلي
- ✅ تتبع الموقع تلقائياً وإرساله للخادم كل 15 ثانية
- ✅ قبول ورفض الطلبات
- ✅ تأكيد التسليم
- ✅ تأكيد الدفع (نقدي / بطاقة / تحويل)
- ✅ الاتصال بالعميل مباشرةً
- ✅ فتح خريطة Google للوصول
- ✅ واتساب العميل
- ✅ إحصائيات اليوم (طلبات، مكتمل، تقييم، أرباح)
- ✅ دعم RTL كامل بخط Cairo

## الإعداد

```bash
# تثبيت المتطلبات
flutter pub get

# للتطوير
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api

# للإنتاج
flutter build apk --dart-define=API_BASE_URL=https://api.shamstores.com/api
```

## هيكل المشروع

```
lib/
├── main.dart              # نقطة دخول التطبيق
├── models/
│   └── order_model.dart   # نماذج البيانات
├── screens/
│   ├── splash_screen.dart # شاشة البداية
│   ├── login_screen.dart  # تسجيل الدخول
│   ├── home_screen.dart   # لوحة التحكم الرئيسية
│   └── order_detail_screen.dart # تفاصيل الطلب
├── services/
│   ├── auth_service.dart     # خدمة المصادقة
│   ├── order_service.dart    # خدمة الطلبات
│   └── location_service.dart # خدمة الموقع
└── utils/
    ├── constants.dart   # الثوابت والألوان
    └── app_theme.dart   # ثيم التطبيق
```

## متطلبات API

يتصل التطبيق بـ endpoints التالية:

| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | /api/auth/login | تسجيل الدخول |
| GET | /api/auth/me | بيانات المستخدم |
| GET | /api/delivery/driver/orders | طلبات السائق |
| PATCH | /api/delivery/orders/:id/status | تحديث حالة الطلب |
| PATCH | /api/delivery/driver/location | تحديث الموقع |
| GET | /api/delivery/stats | إحصائيات اليوم |
| POST | /api/delivery/orders/:id/confirm-payment | تأكيد الدفع |
| POST | /api/delivery/orders/:id/rate | تقييم الطلب |
