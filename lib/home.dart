import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'reserve.dart';
import 'requests.dart';
import 'results.dart';
import 'theme.dart';
import 'track.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, this.locate = currentOrigin});
  final WainApi api;

  /// Where the customer is, for the distance to each shop; null when unknown.
  final Future<Origin?> Function() locate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

Future<Origin?> currentOrigin() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final last = await Geolocator.getLastKnownPosition();
    final position = last ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 6)),
        );
    return Origin(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

class _HomeScreenState extends State<HomeScreen> {
  Meta? meta;
  SearchResult? result;
  bool busy = false;
  String error = '';
  Origin? origin;
  bool located = false;
  List<String> recent = [];
  final query = TextEditingController();
  final scroll = ScrollController();
  final resultsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.api.meta().then((m) {
      if (mounted) setState(() => meta = m);
    }).catchError((_) {});
    loadRecent();
  }

  @override
  void dispose() {
    query.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> loadRecent() async {
    final list = await LocalStore.recent();
    if (mounted) setState(() => recent = list);
  }

  Future<Origin?> where() async {
    if (!located) {
      origin = await widget.locate();
      located = true;
    }
    return origin;
  }

  Future<void> run(Future<SearchResult> Function(Origin? origin) search) async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final found = await search(await where());
      if (!mounted) return;
      setState(() => result = found);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = resultsKey.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 300));
        }
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> searchPhoto(Uint8List bytes) => run((o) => widget.api.searchImage(bytes, origin: o));

  Future<void> capture(ImageSource source) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 85);
    } catch (_) {
      setState(() => error = 'ما كدرنا نفتح الكاميرا. جرّب تختار صورة من المعرض.');
      return;
    }
    if (file == null) return;
    await searchPhoto(await file.readAsBytes());
  }

  Future<void> searchText() async {
    final q = query.text.trim();
    if (q.isEmpty) return;
    await run((o) => widget.api.searchText(q, origin: o));
  }

  Future<void> trySample(int i) async {
    setState(() => busy = true);
    try {
      final bytes = await widget.api.download(widget.api.media('/media/samples/sample_$i.jpg')!);
      setState(() => busy = false);
      await searchPhoto(bytes);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          busy = false;
        });
      }
    }
  }

  Future<void> reserve(Listing listing, String partName) async {
    final code = await showReserveSheet(context, api: widget.api, listing: listing, partName: partName);
    if (code == null || !mounted) return;
    await openReservation(code);
  }

  Future<void> openReservation(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TrackReservationScreen(api: widget.api, code: code),
    ));
    loadRecent();
  }

  Future<void> openRequest(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TrackRequestScreen(api: widget.api, code: code),
    ));
    loadRecent();
  }

  Future<void> ask(Part? suggested) async {
    final meta = this.meta ?? Meta(areas: [], shops: 0, demo: false);
    final code = await Navigator.of(context).push(MaterialPageRoute<String>(
      builder: (_) => RequestScreen(api: widget.api, meta: meta, suggested: suggested, query: result?.query),
    ));
    if (code != null && mounted) await openRequest(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Scaffold(
      appBar: AppBar(
        title: Text('وين ألكاه؟', style: TextStyle(fontFamily: displayFont, fontSize: 24, color: c.tag)),
        actions: [
          TextButton(
            onPressed: () => openUri(context, Uri.parse('${widget.api.baseUrl}/#/shop')),
            child: const Text('عندك محل؟', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        controller: scroll,
        children: [
          if (meta?.demo ?? false)
            Container(
              color: c.tag,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('نسخة تجريبية: المحلات والأسعار والصور كلها للتجربة.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.tagInk, fontSize: 14)),
            ),
          _Sign(
            busy: busy,
            query: query,
            onCamera: () => capture(ImageSource.camera),
            onGallery: () => capture(ImageSource.gallery),
            onSearch: searchText,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error.isNotEmpty) Alert(error),
                if (result != null)
                  KeyedSubtree(
                    key: resultsKey,
                    child: ResultsView(result: result!, api: widget.api, onReserve: reserve, onAsk: ask),
                  )
                else ...[
                  if (recent.isNotEmpty) _Recent(entries: recent, onReservation: openReservation, onRequest: openRequest),
                  if (meta?.demo ?? false) _Samples(api: widget.api, busy: busy, onPick: trySample),
                  const _How(),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(child: Muted('وين ألكاه؟ · بغداد', small: true)),
          ),
        ],
      ),
    );
  }
}

/// The enamel shop sign with the big shutter button.
class _Sign extends StatelessWidget {
  const _Sign({
    required this.busy,
    required this.query,
    required this.onCamera,
    required this.onGallery,
    required this.onSearch,
  });
  final bool busy;
  final TextEditingController query;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Container(
      decoration: BoxDecoration(
        color: c.enamel,
        border: Border(bottom: BorderSide(color: c.tag, width: 8)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 36),
      child: Column(
        children: [
          Text(
            'وين ألكاه؟',
            style: TextStyle(
              fontFamily: displayFont,
              fontSize: 64,
              height: 1.05,
              color: c.tag,
              shadows: [Shadow(color: c.enamelDeep, offset: const Offset(0, 4))],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 28),
            child: Text(
              'صوّر القطعة المكسورة، ونگلك أي محل قريب عنده وحدة، وبيش.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 19),
            ),
          ),
          _Shutter(busy: busy, onTap: onCamera),
          const Padding(
            padding: EdgeInsets.only(top: 26, bottom: 4),
            child: Text('صورة وحدة واضحة، والقطعة بنص الصورة على خلفية سادة.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 14)),
          ),
          TextButton(
            onPressed: busy ? null : onGallery,
            child: const Text('أو اختار صورة من المعرض',
                style: TextStyle(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('search-text'),
                      controller: query,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => onSearch(),
                      style: const TextStyle(color: Color(0xFF14203A)),
                      decoration: const InputDecoration(
                        hintText: 'أو اكتب اسمها: بمب غسالة، كوندنسر…',
                        hintStyle: TextStyle(color: Color(0xFF5B6476)),
                        fillColor: Colors.white,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                  Material(
                    color: c.tag,
                    child: InkWell(
                      onTap: busy ? null : onSearch,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        child: Text('دوّر', style: TextStyle(color: c.tagInk, fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shutter extends StatefulWidget {
  const _Shutter({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_Shutter> createState() => _ShutterState();
}

class _ShutterState extends State<_Shutter> with SingleTickerProviderStateMixin {
  late final spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didUpdateWidget(_Shutter old) {
    super.didUpdateWidget(old);
    if (widget.busy && !spin.isAnimating) spin.repeat();
    if (!widget.busy) spin.stop();
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Semantics(
      button: true,
      label: widget.busy ? 'دا ندوّر' : 'صوّر القطعة',
      hint: 'صورة وحدة واضحة، والقطعة بنص الصورة على خلفية سادة.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: Container(
          width: 196,
          height: 196,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: c.tag, spreadRadius: 16),
              BoxShadow(color: c.enamelDeep, spreadRadius: 10),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: RotationTransition(
                    turns: spin,
                    child: CustomPaint(painter: _DashedRing(c.enamel)),
                  ),
                ),
              ),
              Text(
                widget.busy ? 'دا ندوّر…' : 'صوّر القطعة',
                style: TextStyle(fontFamily: displayFont, fontSize: 30, height: 1.2, color: c.enamelDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  _DashedRing(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final rect = Offset.zero & size;
    const dashes = 36;
    const sweep = 3.141592653589793 * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect.deflate(1.5), i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

class _Samples extends StatelessWidget {
  const _Samples({required this.api, required this.busy, required this.onPick});
  final WainApi api;
  final bool busy;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ما عندك قطعة هسه؟ جرّب وحدة من هذني', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Muted('صور مولّدة للتجربة، والمحلات والأسعار كلها تجريبية.'),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => Semantics(
                  button: true,
                  label: 'صورة تجريبية ${i + 1}',
                  child: InkWell(
                    onTap: busy ? null : () => onPick(i),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.wain.rule, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: NetImage(api.media('/media/samples/sample_$i.jpg'), size: 96),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Recent extends StatelessWidget {
  const _Recent({required this.entries, required this.onReservation, required this.onRequest});
  final List<String> entries;
  final ValueChanged<String> onReservation;
  final ValueChanged<String> onRequest;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('حجوزاتك وطلباتك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final entry in entries)
            if (_parse(entry) case (final kind, final code, final title))
              Card(
                color: c.card,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${kind == 'reservation' ? 'حجز' : 'طلب'} · $code', textDirection: TextDirection.rtl),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => kind == 'reservation' ? onReservation(code) : onRequest(code),
                ),
              ),
        ],
      ),
    );
  }

  static (String, String, String)? _parse(String entry) {
    final match = RegExp(r'^(\w+):([^|]+)\|(.*)$').firstMatch(entry);
    return match == null ? null : (match[1]!, match[2]!, match[3]!);
  }
}

class _How extends StatelessWidget {
  const _How();

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    const steps = [
      ('١', 'تصوّر القطعة', 'نعرف نوعها من شكلها، حتى لو ما تعرف اسمها.'),
      ('٢', 'نشوف المحلات', 'المحلات تحدّث مخزونها، فتشوف منو عنده فعلاً وبيش.'),
      ('٣', 'تحجزها وتروح', 'المحل يحجزها إلك ٣ ساعات، ولا تدفع إلا بالمحل.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('شلون يشتغل؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        for (final (n, title, text) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(n, style: TextStyle(fontFamily: displayFont, fontSize: 34, height: 1.1, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Muted(text),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
