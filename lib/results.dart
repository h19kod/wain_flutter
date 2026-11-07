import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'price_tag.dart';
import 'theme.dart';
import 'widgets.dart';

/// What a search found: the part we think it is, look-alikes to pick from, and the shops.
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.result,
    required this.api,
    required this.onReserve,
    required this.onAsk,
  });

  final SearchResult result;
  final WainApi api;
  final void Function(Listing listing, String partName) onReserve;

  /// Opens the rare-part request, with the part on screen as the suggestion.
  final ValueChanged<Part?> onAsk;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView> {
  int picked = 0;

  @override
  void didUpdateWidget(ResultsView old) {
    super.didUpdateWidget(old);
    if (old.result != widget.result) picked = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    final result = widget.result;

    if (result.candidates.isEmpty) {
      return _Empty(
        title: result.mode == SearchMode.text ? 'ما لكينا قطعة باسم «${result.query}»' : 'ما عرفنا هاي القطعة',
        text: 'اطلبها من المحلات مباشرة. المحل اللي عنده يرسلك سعره.',
        action: FilledButton(onPressed: () => widget.onAsk(null), child: const Text('اطلبها من المحلات')),
      );
    }

    final chosen = result.candidates[picked];
    final part = chosen.part;
    final question = result.mode == SearchMode.text
        ? 'هاي اللي تدور عليها؟'
        : result.unsure
            ? 'مو متأكدين. أي وحدة تشبه قطعتك؟'
            : 'نعتقد قطعتك هي:';
    final count = chosen.listings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (result.photo != null) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.card, width: 3),
                  boxShadow: [BoxShadow(color: c.rule, spreadRadius: 1)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(result.photo!, width: 86, height: 86, fit: BoxFit.cover, semanticLabel: 'صورتك'),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Muted(question),
                    Text(part.nameAr, style: const TextStyle(fontFamily: displayFont, fontSize: 34, height: 1.25)),
                    Muted([if (part.nameEn.isNotEmpty) part.nameEn, part.category.nameAr].join(' · ')),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (result.candidates.length > 1)
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              itemCount: result.candidates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Choice(
                part: result.candidates[i].part,
                imageUrl: widget.api.media(result.candidates[i].part.image),
                selected: i == picked,
                onTap: () => setState(() => picked = i),
              ),
            ),
          ),
        if (part.howToCheck.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 14, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.card,
              border: BorderDirectional(start: BorderSide(color: c.enamel, width: 4)),
            ),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'قبل ما تشتري تأكد من: ', style: TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: part.howToCheck),
            ])),
          ),
        if (part.isIllustration) const Muted('الصور رسوم توضيحية، مو صور القطعة الحقيقية.', small: true),
        if (count > 0) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 10),
            child: Text(
              '${arNumber(count)} ${count == 1 ? 'محل عنده' : 'محلات عندهم'} هاي القطعة',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          PriceTags(listings: chosen.listings, onReserve: (l) => widget.onReserve(l, part.nameAr)),
        ] else
          const _Empty(
            title: 'ماكو محل عنده هاي القطعة هسه',
            text: 'اطلبها، ونوصّل طلبك لكل المحلات المسجلة.',
          ),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: () => widget.onAsk(part),
          child: const Text('ما لكيت قطعتي؟ اطلبها من المحلات'),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.part, required this.imageUrl, required this.selected, required this.onTap});
  final Part part;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: selected ? c.enamel : c.rule, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 108,
            padding: const EdgeInsets.all(6),
            decoration: selected
                ? BoxDecoration(border: Border(bottom: BorderSide(color: c.enamel, width: 4)))
                : null,
            child: Column(
              children: [
                NetImage(imageUrl, size: 64),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(part.nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.text, this.action});
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: context.wain.card, borderRadius: BorderRadius.circular(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            Padding(padding: const EdgeInsets.only(top: 6, bottom: 14), child: Text(text)),
            ?action,
          ],
        ),
      );
}
