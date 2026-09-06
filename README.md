# 🚗 Sham Stores — تطبيق مندوب التوصيل

تطبيق Flutter لمندوبي التوصيل في منصّة شام ستورز.

## المميزات

- تسجيل دخول بـJWT، والتطبيق يرفض أي دور غير `delivery_driver`
- **الطلبات تصل لحظياً** عبر Socket.IO، ودورة استطلاع احتياطية كل ٤٥ ثانية
- زرّ حضور يُبلغ الخادم — لا يُعيَّن طلبٌ لسائق غير متصل
- تتبّع الموقع ورفعه كل ١٥ ثانية أثناء الخدمة
- خريطة تتبّع ملء الشاشة: نقطة الاستلام، ونقطة التسليم، وموقعك، والمسافة المتبقية
- ملاحة بأي تطبيق خرائط مثبّت، واتصال وواتساب بالزبون
- تأكيد التسليم بصورة إثبات، وقبض النقد
- سجلّ الطلبات وأرباح اليوم
- عربية كاملة RTL بخط Cairo

## الإعداد

```bash
flutter pub get
```

للتطوير على خادم محلّي (`10.0.2.2` هو مضيف جهازك من داخل محاكي أندرويد):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api --dart-define=SOCKET_URL=http://10.0.2.2:5000
```

للإنتاج — القيم الافتراضية صحيحة، فلا حاجة إلى أي وسيط:

```bash
flutter build apk --release
```

## الخريطة

يستعمل التطبيق **OpenStreetMap** عبر `flutter_map`، بلا مفتاح API ولا حساب
فوترة. كان يستعمل `google_maps_flutter` بمفتاح `YOUR_GOOGLE_MAPS_API_KEY_HERE`
في `AndroidManifest.xml` — ومفتاحٌ غير صالح لا يعتذر، بل يرسم شبكة رمادية
فارغة يظنّها السائق عطلاً في التطبيق.

## الاتصال بالخادم

`AppConfig.baseUrl` الافتراضي: `https://shamstores.com/api`
`AppConfig.socketUrl` الافتراضي: `https://shamstores.com`

> كان الافتراضي يشير إلى نشرٍ قديم على DigitalOcean لم يعد يعمل، فأي بناء بلا
> `--dart-define` يخرج تطبيقاً لا يتصل بشيء.

### المسارات المستعملة

| Method | Endpoint | الوصف |
|--------|----------|-------|
| POST | `/api/auth/login` | تسجيل الدخول |
| GET | `/api/auth/me` | بيانات المستخدم |
| GET | `/api/delivery/driver/orders` | طلبات السائق النشطة |
| GET | `/api/delivery/driver/history` | سجلّ الطلبات |
| GET | `/api/delivery/driver/earnings` | الأرباح والإحصائيات |
| GET | `/api/delivery/driver/availability` | حالة الحضور |
| POST | `/api/delivery/driver/online` \| `/offline` | تبديل الحضور |
| PATCH | `/api/delivery/driver/location` | تحديث الموقع |
| PATCH | `/api/delivery/orders/:id/status` | تحديث حالة الطلب |
| POST | `/api/delivery/orders/:id/complete` | إكمال الطلب |
| POST | `/api/delivery/orders/:id/proof` | صورة إثبات التسليم |
| POST | `/api/delivery/orders/:id/confirm-payment` | تأكيد قبض المبلغ |

### أحداث Socket.IO

يبثّها الخادم في `backend/src/realtime/socket.ts`، ويُلحَق السائق بغرفته
تلقائياً من الرمز — لا حاجة إلى إرسال `join`.

| الحدث | متى |
|---|---|
| `order:updated` | تعيين طلب أو تغيّر حالته |
| `notification:new` | إشعار جديد |
| `data:changed` | تغيّر بيانات عامّ |

> كان التطبيق يستمع إلى `new_order` و`order_status_updated` — اسمان لا يبثّهما
> الخادم إطلاقاً، فلا يصل السائق شيءٌ لحظةَ تعيينه.

## حالات الطلب

تطابق تعداد Prisma في الخادم حرفاً بحرف:

```
pending · preparing · ready · delivering · delivered · served · cancelled
```

انتقالات السائق: `ready → delivering` عند الاستلام، ثم `delivering → delivered`
عند التسليم.

## هيكل المشروع

```
lib/
├── main.dart
├── models/order_model.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── order_detail_screen.dart
│   ├── tracking_screen.dart      # الخريطة ملء الشاشة
│   ├── history_screen.dart
│   └── earnings_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── order_service.dart
│   ├── location_service.dart
│   └── socket_service.dart
├── widgets/delivery_map.dart
└── utils/
    ├── constants.dart
    ├── formatters.dart           # الليرة السورية والتواريخ بالعربية
    └── app_theme.dart
```

## الفحص

```bash
flutter analyze
```

```bash
flutter test
```
