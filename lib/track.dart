import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

const _status = {
  'held': ('محجوزة', 'القطعة محجوزة إلك. روح للمحل قبل ما ينتهي الوقت، وورّيهم الرمز.'),
  'confirmed': ('أكدها المحل', 'المحل أكد إن القطعة جاهزة إلك.'),
  'completed': ('تم الاستلام', 'استلمت القطعة. إن شاء الله تشتغل.'),
  'cancelled': ('ملغية', 'انلغى هذا الحجز ورجعت القطعة للمحل.'),
  'expired': ('انتهى الوقت', 'خلص وقت الحجز ورجعت القطعة للمحل. تكدر تحجز مرة ثانية إذا بعدها موجودة.'),
};

/// The tilted rubber stamp at the top of a receipt.
class Stamp extends StatelessWidget {
  const Stamp(this.text, {super.key, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Transform.rotate(
            angle: -0.07,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(text, style: TextStyle(fontFamily: displayFont, fontSize: 26, color: color)),
            ),
          ),
        ),
      );
}

class CodeBox extends StatelessWidget {
  const CodeBox({super.key, required this.label, required this.code});
  final String label;
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.rule, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Muted(label, small: true),
          SelectableText(
            code,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 32, letterSpacing: 5.8, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.wain.rule))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: Muted(label)),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class TrackReservationScreen extends StatefulWidget {
  const TrackReservationScreen({super.key, required this.api, required this.code});
  final WainApi api;
  final String code;

  @override
  State<TrackReservationScreen> createState() => _TrackReservationScreenState();
}

class _TrackReservationScreenState extends State<TrackReservationScreen> {
  Reservation? data;
  String error = '';
  bool cancelling = false;
  bool busy = false;
  final phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
    LocalStore.lastPhone().then((v) {
      if (mounted && phone.text.isEmpty) phone.text = v;
    });
  }

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final found = await widget.api.reservation(widget.code);
      if (mounted) setState(() => data = found);
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.status == 404 ? 'ما لكينا حجز بهذا الرمز.' : e.message);
    }
  }

  Future<void> cancel() async {
    if (phone.text.trim().isEmpty) return;
    setState(() {
      error = '';
      busy = true;
    });
    try {
      final updated = await widget.api.cancelReservation(widget.code, phone.text.trim());
      if (mounted) {
        setState(() {
          data = updated;
          cancelling = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('حجزك')),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [_body(context)]),
        ),
      );

  Widget _body(BuildContext context) {
    final c = context.wain;
    final data = this.data;
    if (data == null) {
      return error.isNotEmpty ? Alert(error) : const Muted('دا نجيب الحجز…');
    }
    final (stamp, text) = _status[data.status] ?? (data.status, '');
    final stampColor = switch (data.status) {
      'completed' => c.ok,
      'cancelled' || 'expired' => c.stamp,
      _ => c.accent,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stamp(stamp, color: stampColor),
        Text(data.partName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.35)),
        Text(text),
        CodeBox(label: 'رمز الحجز', code: data.code),
        _Fact('المحل', '${data.shop.name}، ${data.shop.area}'),
        _Fact('العنوان', data.shop.address.isEmpty ? 'اتصل بالمحل للعنوان' : data.shop.address),
        _Fact('المبلغ',
            '${iqd(data.totalIqd)} (${arNumber(data.quantity)} × ${iqd(data.unitPriceIqd)})، تدفعه بالمحل'),
        if (data.isOpen) _Fact('محجوزة لحد', 'الساعة ${clockTime(data.expiresAt)}'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton(onPressed: () => callShop(context, data.shop.phone), child: const Text('اتصل بالمحل')),
            if (data.isOpen && !cancelling)
              OutlinedButton(onPressed: () => setState(() => cancelling = true), child: const Text('ألغِ الحجز')),
          ],
        ),
        if (cancelling) ...[
          const SizedBox(height: 16),
          Labelled(
            label: 'حتى نلغي، اكتب الرقم اللي حجزت بيه',
            child: TextField(
              key: const Key('cancel-phone'),
              controller: phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, children: [
            FilledButton(
              key: const Key('cancel-confirm'),
              onPressed: busy ? null : cancel,
              child: const Text('ألغِ الحجز'),
            ),
            OutlinedButton(onPressed: () => setState(() => cancelling = false), child: const Text('لا، خليه')),
          ]),
        ],
        if (error.isNotEmpty) Alert(error),
        const SizedBox(height: 12),
        const Muted('الرمز محفوظ بالتطبيق، تلكاه بالصفحة الرئيسية.', small: true),
        if (data.shop.isDemo) const Muted('هذا محل تجريبي. ماكو قطعة حقيقية محجوزة.', small: true),
      ],
    );
  }
}
