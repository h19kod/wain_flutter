import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'state.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final server = TextEditingController(text: widget.state.api.baseUrl);
  String? checked;
  bool checking = false;

  @override
  void dispose() {
    server.dispose();
    super.dispose();
  }

  /// Asks the typed server for its catalogue before saving it.
  Future<void> check() async {
    setState(() {
      checking = true;
      checked = null;
    });
    String result;
    try {
      final meta = await WainApi(baseUrl: server.text.trim()).meta();
      result = 'الخادم شغال: ${arNumber(meta.shops)} محل${meta.demo ? '، نسخة تجريبية' : ''}.';
    } on ApiError catch (e) {
      result = e.message;
    } on FormatException {
      result = 'العنوان مو صحيح. مثال: http://192.168.1.20:8000';
    }
    if (mounted) {
      setState(() {
        checked = result;
        checking = false;
      });
    }
  }

  Future<void> save() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.state.setServer(server.text);
    messenger.showSnackBar(const SnackBar(content: Text('انحفظ عنوان الخادم.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const Text('المظهر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('تلقائي')),
                ButtonSegment(value: ThemeMode.light, label: Text('فاتح')),
                ButtonSegment(value: ThemeMode.dark, label: Text('غامق')),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setTheme(s.first),
            ),
            const SizedBox(height: 28),
            const Text('عنوان الخادم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Muted('للتجربة بس. المحاكي يوصل للكمبيوتر على 10.0.2.2، والموبايل الحقيقي على IP الكمبيوتر بنفس الشبكة.',
                small: true),
            const SizedBox(height: 8),
            TextField(
              key: const Key('server-url'),
              controller: server,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(hintText: defaultBaseUrl, hintTextDirection: TextDirection.ltr),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(onPressed: save, child: const Text('احفظ')),
              OutlinedButton(onPressed: checking ? null : check, child: Text(checking ? 'دا نجرب…' : 'جرّب الاتصال')),
              TextButton(
                onPressed: () => server.text = defaultBaseUrl,
                child: const Text('رجّع الافتراضي'),
              ),
            ]),
            if (checked != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(checked!)),
            const SizedBox(height: 28),
            const Muted('وين ألكاه؟ · الإصدار ٠٫٢', small: true),
          ],
        ),
      ),
    );
  }
}
