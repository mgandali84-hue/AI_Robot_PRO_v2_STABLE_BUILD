# AI Robot PRO v2

نسخة جديدة لمشروع المساعد الشخصي AI Robot PRO v2.

## الموجود في النسخة
- واجهة رئيسية مستقبلية شبيهة بالتصميم المعتمد.
- Avatar روبوت تفاعلي: عينان، فم، حالات استماع/تفكير/تحدث/فرح، حركة بسيطة.
- محادثة عربية/إنجليزية.
- Speech-to-Text عبر ميكروفون الهاتف.
- Text-to-Speech بالعربية والإنجليزية.
- ذاكرة شخصية محلية.
- كاميرا.
- واجهة Smart Home تجريبية قابلة للربط.
- شخصيات متعددة.
- اتصال اختياري بخادم AI حقيقي.

## تشغيل الذكاء الاصطناعي الحقيقي
التطبيق لا يضع مفتاح AI السري داخل APK.
يوجد خادم اختياري داخل `server/`.

شغّل الخادم:

```bash
cd server
npm install
OPENAI_API_KEY=ضع_المفتاح_هنا npm start
```

ثم ابنِ التطبيق مع عنوان الخادم:

```bash
flutter pub get
flutter build apk --release --dart-define=AI_SERVER_URL=http://YOUR_SERVER:3000
```

للهواتف عبر الإنترنت استخدم HTTPS وعنوان خادم عام.

## Codemagic
ضع المشروع في GitHub بحيث يكون:

lib/
android/
assets/
server/
pubspec.yaml
codemagic.yaml

ثم شغّل workflow:
`android-release`

## ملاحظة عن الإصدار
مجلد `android/` هنا يحتوي إعدادات Android النصية، لكن ملف `gradle-wrapper.jar` الثنائي قد يكون موجودًا أصلًا في مستودعك الحالي. لا تحذف النسخة العاملة منه. إذا كان موجودًا في مستودعك، اتركه كما هو.

## الحالة
هذه حزمة تطوير v2 وليست ملف APK بحد ذاته. الذكاء السحابي يحتاج خادمًا ومفتاح API، والربط الحقيقي للمنزل الذكي يحتاج Home Assistant/MQTT أو مزود أجهزة.

## Latest update: app icon
The Android launcher icon now uses the approved AI Robot PRO v2 robot image. Standard density PNGs are included under `android/app/src/main/res/mipmap-*` and referenced by `@mipmap/ic_launcher`.

## FIX4
Corrected `speech_to_text` API usage from `options:` to `listenOptions:` for 7.4.x.

## v2 3D Face Animation
The project includes `assets/robot/ai_robot_pro_v2_animated.glb`, a real GLB with named node-animation clips: `Idle`, `Listening`, `Thinking`, `Speaking`, and `Happy`. The app switches animation clips as the assistant state changes.

This is an animation-rig approach (node animations inside GLB), not morph-target facial blend shapes. The current robot asset has separate face components (eyes/smile), so the speaking clip animates the mouth component and the other clips animate the head/eyes/body components.

## Lip Sync v2 update
The robot now includes a GLB with actual mouth morph targets:
`MouthOpen`, `MouthWide`, `MouthRound`.

The app uses `flutter_tts` progress callbacks to map the current spoken word to
`Mouth_A`, `Mouth_E`, `Mouth_O`, or `Mouth_Closed`, with a timed fallback. The current
implementation is a text-derived phoneme heuristic, not a full acoustic phoneme
neural recognizer. A true acoustic phoneme pipeline can later be substituted behind
`PhonemeAnalyzer`.

## Touch Emotion Update
- Tap the robot: triggers a happy response and touch feedback.
- Long press: triggers a thinking/affection response, speech, and animation.
- The GLB remains pinch/drag interactive through `ModelViewer`.
