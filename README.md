# وين ألكاه؟ — تطبيق الموبايل (Flutter، أندرويد)

تطبيق الزبون: يصوّر القطعة أو يكتب اسمها، يشوف القطع المرشحة والمحلات كبطاقات سعر، يحجز، يتابع حجزه، ويطلب القطعة النادرة من المحلات.
يستعمل نفس الـ API مال `WAIN` (Django). بوابة المحلات تبقى بالويب (زر «عندك محل؟» يفتحها بالمتصفح).

## التشغيل

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
cd ~/projects/wain/WAIN/mobile
flutter pub get
flutter analyze
flutter test
```

### على محاكي أندرويد

الخادم لازم يقبل العنوان `10.0.2.2` (هذا عنوان الكمبيوتر من داخل المحاكي):

```bash
cd ~/projects/wain/WAIN && WAIN_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2 ./run.sh
```

```bash
flutter run
```

إذا الخادم شغال أصلاً بدون `10.0.2.2` (يرجع 400)، وصّل المنفذ بـ adb واستعمل 127.0.0.1:

```bash
adb reverse tcp:8000 tcp:8000 && flutter run --dart-define=WAIN_API=http://127.0.0.1:8000
```

### على موبايل حقيقي بنفس الشبكة

شغّل الخادم على `0.0.0.0` وأضف IP الكمبيوتر لـ `WAIN_ALLOWED_HOSTS`، بعدين:
`flutter run --dart-define=WAIN_API=http://192.168.1.20:8000`

نسخة الـ debug تسمح بـ HTTP العادي؛ نسخة الـ release تحتاج HTTPS.

## الملفات

| الملف | شنو بيه |
|---|---|
| `lib/api.dart` | النماذج والاتصال بالـ API (`WainApi`، يقبل `http.Client` للاختبار) |
| `lib/home.dart` | الصفحة الرئيسية: زر التصوير، البحث بالاسم، الصور التجريبية، حجوزاتك |
| `lib/results.dart` | النتائج: صياغة الثقة، القطع المشابهة، «قبل ما تشتري تأكد من» |
| `lib/price_tag.dart` | بطاقة السعر الصفرة لكل محل |
| `lib/reserve.dart` | ورقة الحجز |
| `lib/track.dart` | متابعة الحجز وإلغاؤه |
| `lib/requests.dart` | طلب قطعة نادرة ومتابعة العروض |
| `lib/theme.dart` | ألوان `frontend/src/styles.css` وخطوط Lalezar و IBM Plex Sans Arabic |

الخطوط بـ `assets/fonts` (رخصة SIL OFL).
