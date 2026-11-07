import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';
import 'track.dart';
import 'widgets.dart';

/// Asks every shop for a part the search could not find. Pops with the request code.
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key, required this.api, required this.meta, this.suggested, this.query});
  final WainApi api;
  final Meta meta;
  final Part? suggested;
  final String? query;

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final form = GlobalKey<FormState>();
  late final description = TextEditingController(text: widget.query ?? '');
  final name = TextEditingController();
  final phone = TextEditingController();
  String area = '';
  Uint8List? photo;
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void initState() {
    super.initState();
    LocalStore.lastPhone().then((v) {
      if (mounted && phone.text.isEmpty) phone.text = v;
    });
  }

  @override
  void dispose() {
    description.dispose();
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photo = bytes);
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      final made = await widget.api.requestPart(
        description: description.text.trim(),
        area: area,
        name: name.text.trim(),
        phone: phone.text.trim(),
        suggestedPart: widget.suggested?.id,
        photo: photo,
      );
      await LocalStore.rememberPhone(phone.text.trim());
      await LocalStore.remember('request', made.code, made.description);
      if (mounted) Navigator.of(context).pop(made.code);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          errors = e.asFields;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اطلبها من المحلات')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const Muted('نرسل وصفك وصورتك للمحلات. اسمك ورقمك ما يوصلهم. أنت تشوف عروضهم وتتصل باللي يعجبك.'),
              const SizedBox(height: 14),
              Labelled(
                label: 'شنو القطعة؟ نوع الجهاز وماركته وموديله إذا تعرفه',
                error: errors['description'],
                child: TextFormField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  validator: (v) => (v ?? '').trim().length < 5 ? 'اكتب وصف أطول شوية.' : null,
                ),
              ),
              Labelled(
                label: 'صورة (اختياري)',
                error: errors['image'],
                child: Row(
                  children: [
                    OutlinedButton(onPressed: pickPhoto, child: Text(photo == null ? 'اختار صورة' : 'غيّر الصورة')),
                    if (photo != null) ...[
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(photo!, width: 48, height: 48, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Labelled(
                label: 'منطقتك',
                child: DropdownButtonFormField<String>(
                  initialValue: area,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: '', child: Text('بغداد، أي منطقة')),
                    for (final a in widget.meta.areas) DropdownMenuItem(value: a.name, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => area = v ?? ''),
                ),
              ),
              const SizedBox(height: 12),
              Labelled(
                label: 'اسمك',
                error: errors['customer_name'],
                child: TextFormField(
                  controller: name,
                  validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسمك.' : null,
                ),
              ),
              const SizedBox(height: 12),
              Labelled(
                label: 'رقم موبايلك',
                error: errors['customer_phone'],
                child: TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(hintText: '07XX XXX XXXX', hintTextDirection: TextDirection.ltr),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب رقم موبايلك.' : null,
                ),
              ),
              if (errors['detail'] != null) Alert(errors['detail']!),
              const SizedBox(height: 16),
              FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'دا نرسل…' : 'أرسل الطلب')),
            ],
          ),
        ),
      );
}

class TrackRequestScreen extends StatefulWidget {
  const TrackRequestScreen({super.key, required this.api, required this.code});
  final WainApi api;
  final String code;

  @override
  State<TrackRequestScreen> createState() => _TrackRequestScreenState();
}

class _TrackRequestScreenState extends State<TrackRequestScreen> {
  PartRequest? data;
  String error = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final found = await widget.api.partRequest(widget.code);
      if (mounted) {
        setState(() {
          data = found;
          error = '';
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final c = context.wain;
    return Scaffold(
      appBar: AppBar(title: const Text('طلبك')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (error.isNotEmpty) Alert(error),
            if (data == null && error.isEmpty) const Muted('دا نجيب طلبك…'),
            if (data != null) ...[
              Stamp('طلب مفتوح', color: c.accent),
              Text(data.description, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.35)),
              CodeBox(label: 'رمز الطلب', code: data.code),
              const Text('العروض تظهر هنا أول ما ترسلها المحلات. الرمز محفوظ بالتطبيق.'),
              const SizedBox(height: 12),
              if (data.offers.isEmpty)
                const Muted('بعد ماكو عروض. هاي الصفحة تتحدث وحدها كل نص دقيقة.')
              else
                for (final o in data.offers)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 4,
                      children: [
                        Text(iqd(o.priceIqd), style: const TextStyle(fontFamily: displayFont, fontSize: 24)),
                        Text('${o.shop.name}، ${o.shop.area}'),
                        if (o.note.isNotEmpty) Muted(o.note),
                        FilledButton(onPressed: () => callShop(context, o.shop.phone), child: const Text('اتصل بالمحل')),
                      ],
                    ),
                  ),
              Muted('${arNumber(data.offers.length)} عرض لحد هسه', small: true),
            ],
          ],
        ),
      ),
    );
  }
}
