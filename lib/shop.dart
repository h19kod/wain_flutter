import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'format.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// The shop owner's side: incoming bookings, stock, and customers' rare-part requests.
class ShopPortalScreen extends StatelessWidget {
  const ShopPortalScreen({super.key, required this.state, required this.meta});
  final AppState state;
  final Meta meta;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.signedIn
            ? ShopDashboard(key: ValueKey(state.api.token), state: state, meta: meta)
            : ShopLoginScreen(state: state, meta: meta),
      );
}

class ShopLoginScreen extends StatefulWidget {
  const ShopLoginScreen({super.key, required this.state, required this.meta});
  final AppState state;
  final Meta meta;

  @override
  State<ShopLoginScreen> createState() => _ShopLoginScreenState();
}

class _ShopLoginScreenState extends State<ShopLoginScreen> {
  final form = GlobalKey<FormState>();
  final fields = {for (final k in ['username', 'password', 'name', 'address', 'phone']) k: TextEditingController()};
  String area = '';
  bool registering = false;
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      errors = {};
    });
    final api = widget.state.api;
    final value = {for (final e in fields.entries) e.key: e.value.text.trim()};
    try {
      if (registering) {
        await api.register({...value, 'area': area});
      } else {
        await api.login(value['username']!, fields['password']!.text);
      }
      await widget.state.signedInNow();
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          errors = e.asFields;
          busy = false;
        });
      }
    }
  }

  Widget field(String key, String label, {bool secret = false, bool ltr = false, TextInputType? type, bool required = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Labelled(
          label: label,
          error: errors[key],
          child: TextFormField(
            key: Key('shop-$key'),
            controller: fields[key],
            obscureText: secret,
            keyboardType: type,
            textDirection: ltr || secret ? TextDirection.ltr : null,
            validator: (v) {
              final text = (v ?? '').trim();
              if (required && text.isEmpty) return 'هذا مطلوب.';
              if (secret && registering && text.length < 8) return 'كلمة السر ٨ حروف أو أكثر.';
              return null;
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(registering ? 'سجّل محلك' : 'دخول أصحاب المحلات')),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (registering)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Muted('مجاني للبداية. نتأكد من المحل قبل ما يظهر للزبائن.'),
                ),
              field('username', 'اسم المستخدم', ltr: true),
              field('password', 'كلمة السر', secret: true),
              if (registering) ...[
                field('name', 'اسم المحل'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Labelled(
                    label: 'المنطقة',
                    error: errors['area'],
                    child: DropdownButtonFormField<String>(
                      initialValue: area.isEmpty ? null : area,
                      hint: const Text('اختار'),
                      isExpanded: true,
                      items: [for (final a in widget.meta.areas) DropdownMenuItem(value: a.name, child: Text(a.name))],
                      onChanged: (v) => setState(() => area = v ?? ''),
                      validator: (v) => v == null ? 'اختار المنطقة.' : null,
                    ),
                  ),
                ),
                field('address', 'العنوان', required: false),
                field('phone', 'موبايل المحل', ltr: true, type: TextInputType.phone),
              ],
              if (errors['detail'] != null) Alert(errors['detail']!),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'لحظة…' : registering ? 'سجّل المحل' : 'ادخل'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() {
                  registering = !registering;
                  errors = {};
                }),
                child: Text(registering ? 'عندك حساب؟ ادخل' : 'ما عندك حساب؟ سجّل محلك'),
              ),
            ],
          ),
        ),
      );
}

class ShopDashboard extends StatefulWidget {
  const ShopDashboard({super.key, required this.state, required this.meta});
  final AppState state;
  final Meta meta;

  @override
  State<ShopDashboard> createState() => _ShopDashboardState();
}

class _ShopDashboardState extends State<ShopDashboard> {
  ShopMe? me;
  ShopStats? stats;
  String error = '';

  WainApi get api => widget.state.api;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final found = await api.me();
      if (mounted) setState(() => me = found);
      await refreshStats();
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> refreshStats() async {
    try {
      final found = await api.stats();
      if (mounted) setState(() => stats = found);
    } on ApiError {
      // The numbers are a summary; the tabs still work without them.
    }
  }

  Future<void> signOut() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تطلع من حساب المحل؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('اطلع')),
        ],
      ),
    );
    if (sure ?? false) await widget.state.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    final c = context.wain;
    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('محلك')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: error.isEmpty ? const Muted('دا نجيب محلك…') : Alert(error),
        ),
      );
    }
    final stats = this.stats;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(me.name, style: const TextStyle(fontFamily: displayFont, fontSize: 24, fontWeight: FontWeight.w400)),
          actions: [TextButton(onPressed: signOut, child: const Text('اطلع', style: TextStyle(color: Colors.white)))],
          bottom: TabBar(
            labelColor: c.tag,
            unselectedLabelColor: Colors.white,
            indicatorColor: c.tag,
            labelStyle: const TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'الحجوزات'), Tab(text: 'المخزون'), Tab(text: 'طلبات الزبائن')],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: c.card,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Muted('${me.area} · الخطة ${me.planName}${me.isDemo ? ' · محل تجريبي' : ''}', small: true),
                  if (!me.isVerified)
                    const _Notice('محلك بانتظار التحقق. تكدر تجهز مخزونك هسه، ويظهر للزبائن بعد ما نتصل بيك ونتأكد.'),
                  if (stats != null) _StatsRow(stats: stats),
                  if (stats != null && stats.staleItems > 0)
                    _Notice('${arNumber(stats.staleItems)} صنف ما تأكدت منه من أسبوع. هذني ينزلن لآخر نتائج البحث.'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  BookingsTab(api: api, onChanged: refreshStats),
                  StockTab(api: api, meta: widget.meta, onChanged: refreshStats),
                  WantedTab(api: api),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: WainColors.mix(c.tag, 0.3, c.card), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final ShopStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    final cells = [
      ('حجوزات مفتوحة', arNumber(stats.openReservations)),
      ('بيعات عن طريقنا', arNumber(stats.completedReservations)),
      ('العمولة المستحقة', iqd(stats.commissionDueIqd)),
      ('أصناف', '${arNumber(stats.items)} من ${arNumber(stats.itemLimit)}'),
    ];
    return Row(
      spacing: 6,
      children: [
        for (final (label, value) in cells)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(border: Border.all(color: c.rule), borderRadius: BorderRadius.circular(6)),
              child: Column(
                children: [
                  Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.ink2, height: 1.3)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: const TextStyle(fontFamily: displayFont, fontSize: 20)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared shape of the three tabs: load a list, show errors, pull to refresh.
abstract class _ListTabState<W extends StatefulWidget, T> extends State<W> with AutomaticKeepAliveClientMixin {
  List<T>? rows;
  String error = '';

  Future<List<T>> fetch();
  Widget buildRows(BuildContext context, List<T> rows);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final found = await fetch();
      if (mounted) {
        setState(() {
          rows = found;
          error = '';
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  /// Runs a change, then reloads; any error shows above the list.
  Future<bool> act(Future<void> Function() change) async {
    try {
      await change();
      await load();
      return true;
    } on ApiError catch (e) {
      if (mounted) setState(() => error = e.message);
      await load();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rows = this.rows;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (error.isNotEmpty) Alert(error),
          if (rows == null && error.isEmpty) const Muted('لحظة…') else if (rows != null) buildRows(context, rows),
        ],
      ),
    );
  }
}

// Bookings -------------------------------------------------------------------------

class BookingsTab extends StatefulWidget {
  const BookingsTab({super.key, required this.api, required this.onChanged});
  final WainApi api;
  final VoidCallback onChanged;

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends _ListTabState<BookingsTab, Booking> {
  static const label = {'held': 'جديد', 'confirmed': 'مؤكد', 'completed': 'استلمها', 'cancelled': 'ملغي', 'expired': 'انتهى'};

  @override
  Future<List<Booking>> fetch() => widget.api.bookings();

  Future<void> run(Booking b, String action) async {
    if (action == 'cancel') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تلغي حجز ${b.customerName}؟'),
          content: const Text('القطعة ترجع للمخزون والزبون يشوف إن الحجز انلغى.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ألغِ')),
          ],
        ),
      );
      if (!(sure ?? false)) return;
    }
    if (await act(() => widget.api.bookingAction(b.id, action))) widget.onChanged();
  }

  @override
  Widget buildRows(BuildContext context, List<Booking> rows) {
    if (rows.isEmpty) return const Muted('ماكو حجوزات بعد. الحجوزات الجديدة تظهر هنا.');
    final c = context.wain;
    return Column(
      children: [
        for (final b in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(6),
              border: BorderDirectional(
                start: BorderSide(color: b.status == 'held' ? c.tag : b.isOpen ? c.enamel : c.rule, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${b.partName} × ${arNumber(b.quantity)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    _Pill(label[b.status] ?? b.status, highlight: b.status == 'held'),
                  ],
                ),
                InkWell(
                  onTap: () => callShop(context, b.customerPhone),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${b.customerName} · '),
                    TextSpan(text: b.customerPhone, style: TextStyle(color: c.accent, decoration: TextDecoration.underline)),
                  ])),
                ),
                Muted('الرمز ${b.code} · ${iqd(b.unitPriceIqd * b.quantity)}'
                    '${b.status == 'completed' ? ' · العمولة ${iqd(b.commissionIqd)}' : ''}'
                    '${b.isOpen ? ' · لحد ${clockTime(b.expiresAt)}' : ''}', small: true),
                if (b.isOpen) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (b.status == 'held')
                        OutlinedButton(onPressed: () => run(b, 'confirm'), child: const Text('أكّد إنها جاهزة')),
                      FilledButton(onPressed: () => run(b, 'complete'), child: const Text('الزبون استلمها')),
                      TextButton(onPressed: () => run(b, 'cancel'), child: const Text('ألغِ')),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.highlight = false});
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? c.tag : c.concrete,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: highlight ? c.tagInk : c.ink)),
    );
  }
}

// Stock -------------------------------------------------------------------------------

class StockTab extends StatefulWidget {
  const StockTab({super.key, required this.api, required this.meta, required this.onChanged});
  final WainApi api;
  final Meta meta;
  final VoidCallback onChanged;

  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends _ListTabState<StockTab, StockItem> {
  @override
  Future<List<StockItem>> fetch() => widget.api.inventory();

  Future<void> confirmAll() async {
    final messenger = ScaffoldMessenger.of(context);
    var count = 0;
    if (await act(() async => count = await widget.api.confirmStock())) {
      widget.onChanged();
      messenger.showSnackBar(SnackBar(content: Text('أكدت ${arNumber(count)} صنف. الزبائن يشوفون إن المخزون محدّث.')));
    }
  }

  Future<void> add() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AddStockScreen(api: widget.api, meta: widget.meta),
    ));
    if (added ?? false) {
      await load();
      widget.onChanged();
    }
  }

  Future<void> edit(StockItem item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditStockSheet(api: widget.api, item: item),
    );
    if (changed ?? false) {
      await load();
      widget.onChanged();
    }
  }

  @override
  Widget buildRows(BuildContext context, List<StockItem> rows) {
    final c = context.wain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(onPressed: confirmAll, child: const Text('كل شي بالقائمة صحيح')),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 12),
          child: Muted('اضغطها كل يوم. الزبائن يشوفون آخر مرة أكدت بيها، والقطع اللي ما تأكدت من أسبوع تنزل لآخر النتائج.',
              small: true),
        ),
        OutlinedButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('أضف قطعة للمخزون')),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Muted('مخزونك فارغ. أضف القطع اللي عندك حتى يلكاك الزبائن.'),
        for (final item in rows)
          Card(
            color: c.card,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: item.isStale ? c.stamp : c.rule),
            ),
            child: ListTile(
              onTap: () => edit(item),
              title: Text('${item.partName}${item.condition == 'used' ? ' (مستعمل)' : ''}'),
              subtitle: Text(
                'الكمية ${arNumber(item.quantity)} · محجوز ${arNumber(item.reserved)} · '
                '${item.isStale ? 'ما تأكد من أسبوع' : 'تأكد ${ago(item.lastConfirmedAt)}'}'
                '${item.partApproved ? '' : ' · بانتظار المراجعة'}',
                style: TextStyle(color: item.isStale ? c.stamp : c.ink2, fontSize: 13),
              ),
              trailing: Text(iqd(item.priceIqd), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

class EditStockSheet extends StatefulWidget {
  const EditStockSheet({super.key, required this.api, required this.item});
  final WainApi api;
  final StockItem item;

  @override
  State<EditStockSheet> createState() => _EditStockSheetState();
}

class _EditStockSheetState extends State<EditStockSheet> {
  late final price = TextEditingController(text: '${widget.item.priceIqd}');
  late final quantity = TextEditingController(text: '${widget.item.quantity}');
  Map<String, String> errors = {};
  bool busy = false;

  @override
  void dispose() {
    price.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() change) async {
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      await change();
      if (mounted) Navigator.of(context).pop(true);
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
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(item.partName, style: const TextStyle(fontFamily: displayFont, fontSize: 26)),
            Muted('${item.condition == 'used' ? 'مستعمل' : 'جديد'} · محجوز منها ${arNumber(item.reserved)}'),
            Labelled(
              label: 'السعر بالدينار',
              error: errors['price_iqd'],
              child: TextField(key: const Key('edit-price'), controller: price, keyboardType: TextInputType.number),
            ),
            Labelled(
              label: 'الكمية',
              error: errors['quantity'],
              child: TextField(key: const Key('edit-quantity'), controller: quantity, keyboardType: TextInputType.number),
            ),
            const Muted('الحفظ يحسب تأكيد للصنف هم.', small: true),
            if (errors['detail'] != null) Alert(errors['detail']!),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() => widget.api.updateStock(
                              item.id,
                              price: int.tryParse(price.text.trim()),
                              quantity: int.tryParse(quantity.text.trim()),
                            )),
                    child: const Text('احفظ'),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy || item.reserved > 0 ? null : () => run(() => widget.api.removeStock(item.id)),
                  child: const Text('شيلها'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key, required this.api, required this.meta});
  final WainApi api;
  final Meta meta;

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final search = TextEditingController();
  final price = TextEditingController();
  final quantity = TextEditingController(text: '1');
  Timer? debounce;
  List<Part> found = [];
  Part? adding;
  String condition = 'new';
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    price.dispose();
    quantity.dispose();
    super.dispose();
  }

  void typed(String text) {
    debounce?.cancel();
    setState(() => adding = null);
    if (text.trim().isEmpty) {
      setState(() => found = []);
      return;
    }
    debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final parts = await widget.api.pickParts(text.trim());
        if (mounted && search.text == text) setState(() => found = parts);
      } on ApiError catch (e) {
        if (mounted) setState(() => errors = {'detail': e.message});
      }
    });
  }

  Future<void> save() async {
    final part = adding!;
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      await widget.api.addStock(
        part: part.id,
        price: int.tryParse(price.text.trim()) ?? 0,
        quantity: int.tryParse(quantity.text.trim()) ?? 0,
        condition: condition,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          errors = e.asFields;
          busy = false;
        });
      }
    }
  }

  Future<void> propose() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProposePartSheet(api: widget.api, meta: widget.meta, name: search.text.trim()),
    );
    if ((sent ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('وصلتنا. نراجعها ونضيفها للبحث خلال يوم، وتظهر هنا بالبحث حتى تضيفها لمخزونك.')),
      );
      typed(search.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final part = adding;
    return Scaffold(
      appBar: AppBar(title: const Text('أضف قطعة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          TextField(
            key: const Key('stock-search'),
            controller: search,
            onChanged: typed,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'اكتب اسمها…', prefixIcon: Icon(Icons.search)),
          ),
          if (errors['detail'] != null) Alert(errors['detail']!),
          if (part == null) ...[
            for (final p in found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: NetImage(widget.api.media(p.image), size: 44),
                title: Text(p.nameAr),
                subtitle: Text(p.category.nameAr),
                onTap: () => setState(() => adding = p),
              ),
            if (search.text.trim().length > 1)
              TextButton(onPressed: propose, child: const Text('القطعة مو موجودة؟ أضفها للكتالوج')),
          ] else ...[
            const SizedBox(height: 16),
            Text(part.nameAr, style: const TextStyle(fontFamily: displayFont, fontSize: 26)),
            const SizedBox(height: 12),
            Labelled(
              label: 'السعر بالدينار',
              error: errors['price_iqd'],
              child: TextField(key: const Key('add-price'), controller: price, keyboardType: TextInputType.number),
            ),
            const SizedBox(height: 12),
            Labelled(
              label: 'الكمية',
              error: errors['quantity'],
              child: TextField(key: const Key('add-quantity'), controller: quantity, keyboardType: TextInputType.number),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'new', label: Text('جديد')),
                ButtonSegment(value: 'used', label: Text('مستعمل')),
              ],
              selected: {condition},
              onSelectionChanged: (s) => setState(() => condition = s.first),
            ),
            FieldError(errors['part']),
            const SizedBox(height: 16),
            FilledButton(onPressed: busy ? null : save, child: const Text('أضف للمخزون')),
          ],
        ],
      ),
    );
  }
}

class ProposePartSheet extends StatefulWidget {
  const ProposePartSheet({super.key, required this.api, required this.meta, required this.name});
  final WainApi api;
  final Meta meta;
  final String name;

  @override
  State<ProposePartSheet> createState() => _ProposePartSheetState();
}

class _ProposePartSheetState extends State<ProposePartSheet> {
  late final name = TextEditingController(text: widget.name);
  int? category;
  Uint8List? photo;
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => photo = bytes);
  }

  Future<void> send() async {
    if (photo == null || category == null) {
      setState(() => errors = {'detail': 'اختار القسم وصوّر القطعة.'});
      return;
    }
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      await widget.api.proposePart(name: name.text.trim(), category: category!, photo: photo!);
      if (mounted) Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              const Text('أضف قطعة للكتالوج', style: TextStyle(fontFamily: displayFont, fontSize: 26)),
              Labelled(label: 'اسم القطعة', error: errors['name_ar'], child: TextField(controller: name)),
              Labelled(
                label: 'القسم',
                error: errors['category'],
                child: DropdownButtonFormField<int>(
                  initialValue: category,
                  hint: const Text('اختار'),
                  isExpanded: true,
                  items: [for (final c in widget.meta.categories) DropdownMenuItem(value: c.id, child: Text(c.nameAr))],
                  onChanged: (v) => setState(() => category = v),
                ),
              ),
              Labelled(
                label: 'صورة واضحة للقطعة',
                error: errors['image'],
                child: Row(children: [
                  OutlinedButton(onPressed: pick, child: Text(photo == null ? 'صوّرها' : 'صوّرها مرة ثانية')),
                  if (photo != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(photo!, width: 48, height: 48, fit: BoxFit.cover),
                    ),
                  ],
                ]),
              ),
              const Muted('نراجعها ونضيفها للبحث خلال يوم. بعدها تكدر تضيفها لمخزونك.', small: true),
              if (errors['detail'] != null) Alert(errors['detail']!),
              FilledButton(onPressed: busy ? null : send, child: const Text('أرسل للمراجعة')),
            ],
          ),
        ),
      );
}

// Customers' requests ---------------------------------------------------------------

class WantedTab extends StatefulWidget {
  const WantedTab({super.key, required this.api});
  final WainApi api;

  @override
  State<WantedTab> createState() => _WantedTabState();
}

class _WantedTabState extends _ListTabState<WantedTab, OpenRequest> {
  List<Demand> demand = [];

  @override
  Future<List<OpenRequest>> fetch() async {
    widget.api.demand().then((d) {
      if (mounted) setState(() => demand = d);
    }).catchError((Object _) {});
    return widget.api.openRequests();
  }

  Future<void> offer(OpenRequest r) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OfferSheet(api: widget.api, request: r),
    );
    if (sent ?? false) await load();
  }

  @override
  Widget buildRows(BuildContext context, List<OpenRequest> rows) {
    final c = context.wain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (demand.isNotEmpty) ...[
          const Text('الناس تدوّر عليها وانت ما عندك (آخر ٣٠ يوم)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final d in demand)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(d.name)),
                Muted('${arNumber(d.searches)} بحث', small: true),
              ]),
            ),
          const Divider(height: 28),
        ],
        const Text('زبائن يدورون على قطع نادرة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Muted('ماكو طلبات مفتوحة هسه.'),
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.image != null) ...[
                      NetImage(widget.api.media(r.image), size: 64),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Muted('${r.area.isEmpty ? 'بغداد' : r.area} · ${ago(r.createdAt)}', small: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (r.myOfferIqd != null)
                  Text('أرسلت عرض بـ ${iqd(r.myOfferIqd!)}', style: TextStyle(color: c.ok))
                else
                  FilledButton(onPressed: () => offer(r), child: const Text('أرسل عرض')),
              ],
            ),
          ),
      ],
    );
  }
}

class OfferSheet extends StatefulWidget {
  const OfferSheet({super.key, required this.api, required this.request});
  final WainApi api;
  final OpenRequest request;

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  final price = TextEditingController();
  final note = TextEditingController();
  bool busy = false;
  Map<String, String> errors = {};

  @override
  void dispose() {
    price.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> send() async {
    setState(() {
      busy = true;
      errors = {};
    });
    try {
      await widget.api.sendOffer(widget.request.id, price: int.tryParse(price.text.trim()) ?? 0, note: note.text.trim());
      if (mounted) Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(widget.request.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Labelled(
                label: 'سعرك بالدينار',
                error: errors['price_iqd'],
                child: TextField(key: const Key('offer-price'), controller: price, keyboardType: TextInputType.number),
              ),
              Labelled(
                label: 'ملاحظة',
                error: errors['note'],
                child: TextField(
                  controller: note,
                  maxLength: 240,
                  decoration: const InputDecoration(hintText: 'أصلي، مستعمل نظيف…'),
                ),
              ),
              const Muted('الزبون يشوف سعرك ورقم محلك، ويتصل بيك إذا عجبه.', small: true),
              if (errors['detail'] != null) Alert(errors['detail']!),
              FilledButton(onPressed: busy ? null : send, child: const Text('أرسل العرض')),
            ],
          ),
        ),
      );
}
