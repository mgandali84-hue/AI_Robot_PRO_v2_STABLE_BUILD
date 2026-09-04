import 'dart:convert';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'phoneme_analyzer.dart';

const aiServerUrl = String.fromEnvironment(
  'AI_SERVER_URL',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(AIRobotPROV2(cameras: cameras));
}

class AIRobotPROV2 extends StatelessWidget {
  final List<CameraDescription> cameras;
  const AIRobotPROV2({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Robot PRO v2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05080D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF178BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(cameras: cameras),
    );
  }
}

class ChatItem {
  final String text;
  final bool robot;
  ChatItem(this.text, this.robot);
}

class RobotBrain {
  String? configuredServerUrl;

  String get serverUrl => (configuredServerUrl ?? aiServerUrl).trim();

  bool get cloudAiConfigured => serverUrl.isNotEmpty;
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();
  final List<String> memory = [];
  SharedPreferences? prefs;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    configuredServerUrl = prefs?.getString('ai_server_url') ?? '';
    memory
      ..clear()
      ..addAll(prefs?.getStringList('memory') ?? []);
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.0);
    await tts.setVolume(1.0);
  }

  Future<String> ask(String prompt, String language) async {
    if (serverUrl.isNotEmpty) {
      try {
        final response = await http
            .post(
              Uri.parse('${serverUrl.replaceAll(RegExp(r'/+$'), '')}/chat'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'message': prompt,
                'language': language,
                'memory': memory.take(30).toList(),
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final answer = data['answer'];
          if (answer is String && answer.trim().isNotEmpty) return answer.trim();
        }
      } catch (_) {}
    }

    final p = prompt.toLowerCase();
    if (p.contains('مرحبا') || p.contains('اهلا') || p.contains('hello') || p.contains('hi')) {
      return language == 'ar'
          ? 'أهلاً بك! أنا AI Robot PRO v2. كيف أستطيع مساعدتك؟'
          : 'Hello! I am AI Robot PRO v2. How can I help you?';
    }
    if (p.contains('اسمك') || p.contains('name')) {
      return language == 'ar'
          ? 'اسمي AI Robot PRO v2.'
          : 'My name is AI Robot PRO v2.';
    }
    if (RegExp(r'(تذكر|احفظ|remember|save)', caseSensitive: false).hasMatch(prompt)) {
      final value = prompt
          .replaceFirst(RegExp(r'(تذكر|احفظ|remember|save)\s*', caseSensitive: false), '')
          .trim();
      if (value.isNotEmpty) {
        memory.add(value);
        await prefs?.setStringList('memory', memory);
      }
      return language == 'ar' ? 'تم حفظ المعلومة في ذاكرتي.' : 'I saved that in my memory.';
    }
    if (p.contains('ذاكرة') || p.contains('memory')) {
      return memory.isEmpty
          ? (language == 'ar' ? 'لا توجد معلومات محفوظة حاليًا.' : 'There are no saved memories yet.')
          : (language == 'ar'
              ? 'لدي ${memory.length} معلومة محفوظة.'
              : 'I have ${memory.length} saved memories.');
    }
    return language == 'ar'
        ? 'الذكاء السحابي غير مربوط حاليًا. افتح إعدادات 🧠 وأدخل رابط خادم AI لتفعيل المساعد الحقيقي.'
        : 'Cloud AI is not configured yet. Open 🧠 settings and enter your AI server URL to enable the real assistant.';
  }

  Future<void> speak(String text, String language) async {
    await tts.setLanguage(language == 'ar' ? 'ar-SA' : 'en-US');
    await tts.speak(text);
  }

  Future<bool> startListening({
    required String language,
    required ValueChanged<String> onText,
    required VoidCallback onDone,
  }) async {
    final ok = await speech.initialize();
    if (!ok) return false;
    await speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: language == 'ar' ? 'ar_SA' : 'en_US',
      ),
      onResult: (result) {
        onText(result.recognizedWords);
        if (result.finalResult) onDone();
      },
    );
    return true;
  }
}

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final brain = RobotBrain();
  final messageController = TextEditingController();
  final messages = <ChatItem>[];

  late final AnimationController pulse;
  String language = 'ar';
  String emotion = 'idle';
  String character = 'Metal Classic';
  bool listening = false;
  bool thinking = false;
  int navIndex = 0;
  String _animationName = 'Idle';
  Timer? _lipSyncTimer;
  bool _ttsProgressSeen = false;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    brain.tts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        emotion = 'talking';
        _animationName = 'Mouth_A';
      });
    });
    brain.tts.setProgressHandler((String _, int __, int ___, String word) {
      _ttsProgressSeen = true;
      final shape = PhonemeAnalyzer.fromWord(word, language: language);
      if (!mounted) return;
      setState(() => _animationName = shape.animationName);
    });
    brain.tts.setCompletionHandler(() {
      _lipSyncTimer?.cancel();
      if (!mounted) return;
      setState(() {
        emotion = 'happy';
        _animationName = 'Happy';
      });
    });
    brain.tts.setErrorHandler((_) {
      _lipSyncTimer?.cancel();
      if (!mounted) return;
      setState(() {
        emotion = 'idle';
        _animationName = 'Idle';
      });
    });
    brain.init().then((_) {
      setState(() {
        messages.add(ChatItem(
          language == 'ar'
              ? 'مرحباً 👋 أنا مساعدك الشخصي. كيف أستطيع مساعدتك اليوم؟'
              : 'Hello 👋 I am your personal assistant. How can I help today?',
          true,
        ));
      });
    });
  }

  @override
  void dispose() {
    pulse.dispose();
    messageController.dispose();
    _lipSyncTimer?.cancel();
    brain.tts.stop();
    super.dispose();
  }

  void _startFallbackLipSync(String text) {
    _lipSyncTimer?.cancel();
    _ttsProgressSeen = false;
    final sequence = PhonemeAnalyzer.sequenceForText(text, language: language);
    var index = 0;
    _lipSyncTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted || _ttsProgressSeen || sequence.isEmpty) {
        _lipSyncTimer?.cancel();
        return;
      }
      setState(() => _animationName = sequence[index % sequence.length]);
      index++;
    });
  }

  Future<void> sendMessage([String? incoming]) async {
    final text = (incoming ?? messageController.text).trim();
    if (text.isEmpty) return;
    messageController.clear();
    setState(() {
      messages.add(ChatItem(text, false));
      thinking = true;
      emotion = 'thinking';
      _animationName = 'Thinking';
    });
    final reply = await brain.ask(text, language);
    if (!mounted) return;
    setState(() {
      thinking = false;
      emotion = 'talking';
      _animationName = 'Mouth_A';
      messages.add(ChatItem(reply, true));
    });
    _startFallbackLipSync(reply);
    await brain.speak(reply, language);
    _lipSyncTimer?.cancel();
    if (mounted) setState(() { emotion = 'happy'; _animationName = 'Happy'; });
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() { emotion = 'idle'; _animationName = 'Idle'; });
  }

  Future<void> toggleMic() async {
    if (listening) {
      await brain.speech.stop();
      if (mounted) {
        setState(() {
          listening = false;
          emotion = 'idle';
          _animationName = 'Idle';
        });
      }
      return;
    }
    setState(() {
      listening = true;
      emotion = 'listening';
      _animationName = 'Listening';
    });
    final ok = await brain.startListening(
      language: language,
      onText: (text) {
        messageController.text = text;
        setState(() {});
      },
      onDone: () {
        if (mounted) {
          setState(() => listening = false);
          if (messageController.text.trim().isNotEmpty) sendMessage();
        }
      },
    );
    if (!ok && mounted) {
      setState(() {
        listening = false;
        emotion = 'idle';
        _animationName = 'Idle';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(language == 'ar'
              ? 'تعذر تشغيل الميكروفون. تأكد من صلاحية الميكروفون.'
              : 'Microphone unavailable. Check microphone permission.'),
        ),
      );
    }
  }


  void _touchRobot() {
    setState(() {
      emotion = 'happy';
      _animationName = 'Happy';
    });
    final reply = language == 'ar'
        ? 'أشعر بلمستك 😊'
        : 'I can feel your touch 😊';
    messages.add(ChatItem(reply, true));
    brain.speak(reply, language);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        emotion = 'idle';
        _animationName = 'Idle';
      });
    });
  }

  void _longPressRobot() {
    setState(() {
      emotion = 'thinking';
      _animationName = 'Thinking';
    });
    final reply = language == 'ar'
        ? 'أنا هنا معك 🤖❤️'
        : 'I am here with you 🤖❤️';
    messages.add(ChatItem(reply, true));
    brain.speak(reply, language);
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() {
        emotion = 'happy';
        _animationName = 'Happy';
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          emotion = 'idle';
          _animationName = 'Idle';
        });
      });
    });
  }

  void openCamera() {
    if (widget.cameras.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPage(camera: widget.cameras.first),
      ),
    );
  }

  void showMemory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(language == 'ar' ? '🧠 الذاكرة الشخصية' : '🧠 Personal Memory',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (brain.memory.isEmpty)
                    Text(language == 'ar' ? 'الذاكرة فارغة.' : 'Memory is empty.')
                  else
                    SizedBox(
                      height: 300,
                      child: ListView(
                        children: brain.memory.reversed
                            .map((m) => ListTile(
                                  leading: const Icon(Icons.bookmark_outline),
                                  title: Text(m),
                                ))
                            .toList(),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: () async {
                      brain.memory.clear();
                      await brain.prefs?.setStringList('memory', brain.memory);
                      setSheet(() {});
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: Text(language == 'ar' ? 'حذف الذاكرة' : 'Clear memory'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showAiSettings() {
    final controller = TextEditingController(text: brain.serverUrl);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          18, 18, 18, 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                language == 'ar' ? '🧠 ربط الذكاء الاصطناعي' : '🧠 Cloud AI Connection',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                language == 'ar'
                    ? 'أدخل عنوان خادم AI الخاص بك. لا تضع مفتاح API داخل التطبيق.'
                    : 'Enter your AI server URL. Never put an API key inside the APK.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: language == 'ar' ? 'رابط الخادم' : 'AI server URL',
                  hintText: 'https://your-server.example.com',
                  prefixIcon: const Icon(Icons.cloud_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        controller.text = '';
                        await brain.prefs?.remove('ai_server_url');
                        brain.configuredServerUrl = '';
                        if (mounted) setState(() {});
                      },
                      child: Text(language == 'ar' ? 'مسح' : 'Clear'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final value = controller.text.trim();
                        brain.configuredServerUrl = value;
                        if (value.isEmpty) {
                          await brain.prefs?.remove('ai_server_url');
                        } else {
                          await brain.prefs?.setString('ai_server_url', value);
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      },
                      child: Text(language == 'ar' ? 'حفظ' : 'Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                brain.cloudAiConfigured
                    ? (language == 'ar' ? '🟢 الخادم مضبوط' : '🟢 Server configured')
                    : (language == 'ar' ? '🟠 الذكاء السحابي غير مربوط بعد' : '🟠 Cloud AI is not configured yet'),
                style: const TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showCharacters() {
    final chars = [
      ('Metal Classic', '🤖', 'مساعد شخصي'),
      ('Space AI', '🚀', 'مستكشف'),
      ('Teacher Bot', '📚', 'تعليمي'),
      ('Friend Bot', '😊', 'رفيق'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: chars.map((c) {
          return ListTile(
            leading: Text(c.$2, style: const TextStyle(fontSize: 28)),
            title: Text(c.$1),
            subtitle: Text(c.$3),
            trailing: character == c.$1 ? const Icon(Icons.check_circle, color: Colors.cyan) : null,
            onTap: () async {
              setState(() => character = c.$1);
              await brain.prefs?.setString('character', character);
              if (mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void showSmartHome() {
    final devices = <String, bool>{
      'الإضاءة': false,
      'التلفاز': false,
      'التكييف': false,
    };
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text('🏠 Smart Home',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...devices.keys.map((d) => SwitchListTile(
                  title: Text(d),
                  value: devices[d]!,
                  onChanged: (v) {
                    devices[d] = v;
                    setSheet(() {});
                  },
                )),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'واجهة التحكم جاهزة للربط مع Home Assistant أو MQTT. الأجهزة الحالية محاكاة.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = language == 'ar';
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF05080D),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: RichText(
            text: const TextSpan(
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              children: [
                TextSpan(text: 'AI Robot '),
                TextSpan(text: 'PRO v2', style: TextStyle(color: Colors.cyanAccent)),
              ],
            ),
          ),
          leading: IconButton(onPressed: showCharacters, icon: const Icon(Icons.menu)),
          actions: [
            IconButton(onPressed: showAiSettings, icon: const Icon(Icons.psychology_outlined)),
            IconButton(onPressed: () => setState(() => language = language == 'ar' ? 'en' : 'ar'),
                icon: Text(language == 'ar' ? 'EN' : 'ع')),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Chip(
                  avatar: const CircleAvatar(radius: 5, backgroundColor: Colors.greenAccent),
                  label: Text(brain.cloudAiConfigured ? 'ONLINE AI' : 'LOCAL / OFFLINE'),
                ),
                Text(character, style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                rtl ? 'المس الروبوت للتفاعل معه • اضغط مطولاً للمزيد من التفاعل'
                    : 'Tap the robot to interact • Long-press for more',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              height: 430,
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: _touchRobot,
                onLongPress: _longPressRobot,
                child: Robot3DAvatar(
                  animationName: _animationName,
                  statusText: emotion == 'thinking'
                    ? (rtl ? 'أفكر...' : 'Thinking...')
                    : emotion == 'listening'
                        ? (rtl ? 'أستمع إليك...' : 'Listening...')
                        : emotion == 'talking'
                            ? (rtl ? 'أتحدث وأحرك الفم...' : 'Speaking + Lip Sync...')
                            : emotion == 'happy'
                                ? (rtl ? 'سعيد بمساعدتك' : 'Happy to help')
                                : (rtl ? 'كيف أساعدك؟' : 'How can I help?'),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  ...messages.map((m) => Align(
                        alignment: m.robot ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(13),
                          constraints: const BoxConstraints(maxWidth: 350),
                          decoration: BoxDecoration(
                            color: m.robot ? const Color(0xFF101A25) : const Color(0xFF0C2C40),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: m.robot
                                  ? Colors.white12
                                  : Colors.cyanAccent.withValues(alpha: .18),
                            ),
                          ),
                          child: Text(m.text, style: const TextStyle(fontSize: 15.5)),
                        ),
                      )),
                  if (thinking)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('•••', style: TextStyle(color: Colors.cyanAccent, fontSize: 25)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _FeatureTile(icon: Icons.chat_bubble_outline, label: language == 'ar' ? 'المحادثة' : 'Chat'),
                  _FeatureTile(icon: Icons.camera_alt_outlined, label: language == 'ar' ? 'الرؤية' : 'Vision'),
                  _FeatureTile(icon: Icons.psychology_outlined, label: language == 'ar' ? 'الذاكرة' : 'Memory'),
                  _FeatureTile(icon: Icons.phone_android_outlined, label: language == 'ar' ? 'الهاتف' : 'Phone'),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF081019),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: toggleMic,
                          style: IconButton.styleFrom(
                            backgroundColor: listening ? Colors.redAccent : const Color(0xFF1266CC),
                          ),
                          icon: Icon(listening ? Icons.stop : Icons.mic),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: messageController,
                            onSubmitted: (_) => sendMessage(),
                            decoration: InputDecoration(
                              hintText: rtl ? 'اكتب رسالتك...' : 'Type your message...',
                              filled: true,
                              fillColor: const Color(0xFF0D141D),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => sendMessage(),
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _QuickAction(icon: Icons.chat_bubble_outline, text: rtl ? 'المحادثة' : 'Chat',
                            onTap: () => setState(() => navIndex = 1)),
                        _QuickAction(icon: Icons.camera_alt_outlined, text: rtl ? 'الرؤية' : 'Vision',
                            onTap: openCamera),
                        _QuickAction(icon: Icons.psychology_outlined, text: rtl ? 'الذاكرة' : 'Memory',
                            onTap: showMemory),
                        _QuickAction(icon: Icons.home_outlined, text: rtl ? 'المنزل' : 'Home',
                            onTap: showSmartHome),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1620),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: Colors.cyanAccent),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: Colors.cyanAccent),
                const SizedBox(height: 3),
                Text(text, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}

class Robot3DAvatar extends StatelessWidget {
  final String animationName;
  final String statusText;
  const Robot3DAvatar({super.key, required this.animationName, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ModelViewer(
            src: 'assets/robot/ai_robot_pro_v2_lipsync.glb',
            alt: 'AI Robot PRO v2 interactive 3D avatar',
            cameraControls: true,
            disablePan: true,
            autoRotate: false,
            autoPlay: true,
            animationName: animationName,
            animationCrossfadeDuration: 250,
            backgroundColor: Colors.transparent,
            exposure: 1.0,
            shadowIntensity: 1.0,
            disableZoom: false,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xCC07111B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: .18)),
            ),
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;
  const CameraPage({super.key, required this.camera});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraController controller;
  late final Future<void> init;
  @override
  void initState() {
    super.initState();
    controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    init = controller.initialize();
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AI Vision')),
        body: FutureBuilder<void>(
          future: init,
          builder: (_, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return Center(child: Text('Camera error: ${snap.error}'));
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned(
                  left: 20, right: 20, bottom: 25,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final photo = await controller.takePicture();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Captured: ${photo.path}')),
                      );
                    },
                    icon: const Icon(Icons.camera),
                    label: const Text('Capture'),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
