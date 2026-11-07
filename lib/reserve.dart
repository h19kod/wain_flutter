import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the reserve sheet; completes with the reservation code once it is made.
Future<String?> showReserveSheet(BuildContext context, {required WainApi api, required Listing listing, required String partName}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: const Color(0x8C081228),
      builder: (_) => ReserveSheet(api: api, listing: listing, partName: partName),
    );

class ReserveSheet extends StatefulWidget {
  const ReserveSheet({super.key, required this.api, required this.listing, required this.partName});
  final WainApi api;
  final Listing listing;
  final String partName;

  @override
  State<ReserveSheet> createState() => _ReserveSheetState();
}

class _ReserveSheetState extends State<ReserveSheet> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  int quantity = 1;
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void initState() {
    super.initState();
    LocalStore.lastPhone().then((value) {
      if (mounted && phone.text.isEmpty) phone.text = value;
    });
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      final made = await widget.api.reserve(
        inventory: widget.listing.id,
        quantity: quantity,
        name: name.text.trim(),
        phone: phone.text.trim(),
      );
      await LocalStore.rememberPhone(phone.text.trim());
      await LocalStore.remember('reservation', made.code, made.partName);
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
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final most = listing.available.clamp(1, 10);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text('احجز ${widget.partName}', style: const TextStyle(fontFamily: displayFont, fontSize: 28, height: 1.3)),
              Muted('من ${listing.shop.name}، ${listing.shop.area}. السعر ${iqd(listing.priceIqd)} للوحدة، وتدفع بالمحل.'),
              Labelled(
                label: 'اسمك',
                error: errors['customer_name'],
                child: TextFormField(
                  key: const Key('reserve-name'),
                  controller: name,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().length < 2 ? 'اكتب اسمك.' : null,
                ),
              ),
              Labelled(
                label: 'رقم موبايلك',
                error: errors['customer_phone'],
                child: TextFormField(
                  key: const Key('reserve-phone'),
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(hintText: '07XX XXX XXXX', hintTextDirection: TextDirection.ltr),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب رقم موبايلك.' : null,
                ),
              ),
              const Muted('الرقم يشوفه هذا المحل بس، حتى يتصل بيك إذا احتاج.', small: true),
              if (listing.available > 1)
                Labelled(
                  label: 'الكمية',
                  error: errors['quantity'],
                  child: DropdownButtonFormField<int>(
                    initialValue: quantity,
                    items: [
                      for (var i = 1; i <= most; i++) DropdownMenuItem(value: i, child: Text(arNumber(i))),
                    ],
                    onChanged: (v) => setState(() => quantity = v ?? 1),
                  ),
                ),
              if (errors['detail'] != null) Alert(errors['detail']!),
              Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      child: Text(busy ? 'دا نحجز…' : 'احجز بـ ${iqd(listing.priceIqd * quantity)}'),
                    ),
                  ),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
