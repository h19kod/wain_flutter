import 'package:flutter/material.dart';

import 'api.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets.dart';

/// A shop listing drawn as a yellow price tag with a string hole and a notch.
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.listing, required this.onReserve});
  final Listing listing;
  final ValueChanged<Listing> onReserve;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    final shop = listing.shop;
    final tagColor = listing.isStale ? WainColors.mix(c.tag, 0.45, c.card) : c.tag;
    final where = [
      shop.area,
      if (listing.distanceKm != null) 'يبعد ${arNumber(listing.distanceKm!)} كم',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipPath(
              clipper: _TagNotch(Directionality.of(context)),
              child: Container(
                width: 132,
                color: tagColor,
                padding: const EdgeInsets.fromLTRB(8, 30, 8, 18),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -18,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: c.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC79D10), width: 2),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            iqd(listing.priceIqd),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: displayFont, fontSize: 26, height: 1.15, color: c.tagInk),
                          ),
                          Text(listing.condition == 'used' ? 'مستعمل' : 'جديد',
                              style: TextStyle(fontSize: 14, color: c.tagInk)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text(where, style: const TextStyle(fontSize: 14)),
                    Text(
                      listing.isStale
                          ? 'ما تأكد التوفر من أسبوع أو أكثر. اتصل قبل لا تروح.'
                          : freshness(listing.lastConfirmedAt),
                      style: TextStyle(fontSize: 14, color: listing.isStale ? c.stamp : c.ok),
                    ),
                    Muted('متوفر ${arNumber(listing.available)}', small: true),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(onPressed: () => onReserve(listing), child: const Text('احجزها')),
                        OutlinedButton(onPressed: () => callShop(context, shop.phone), child: const Text('اتصل بالمحل')),
                        if (shop.latitude != null && shop.longitude != null)
                          OutlinedButton(
                            onPressed: () => openUri(
                              context,
                              Uri.https('www.google.com', '/maps/search/', {
                                'api': '1',
                                'query': '${shop.latitude},${shop.longitude}',
                              }),
                            ),
                            child: const Text('الموقع'),
                          ),
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

/// Cuts a V notch into the tag's inner edge, halfway down.
class _TagNotch extends CustomClipper<Path> {
  _TagNotch(this.direction);
  final TextDirection direction;

  @override
  Path getClip(Size size) {
    final mid = size.height / 2;
    final inner = direction == TextDirection.rtl ? 0.0 : size.width;
    final depth = direction == TextDirection.rtl ? 12.0 : -12.0;
    final outer = size.width - inner;
    return Path()
      ..moveTo(outer, 0)
      ..lineTo(inner, 0)
      ..lineTo(inner, mid - 14)
      ..lineTo(inner + depth, mid)
      ..lineTo(inner, mid + 14)
      ..lineTo(inner, size.height)
      ..lineTo(outer, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_TagNotch old) => old.direction != direction;
}

class PriceTags extends StatelessWidget {
  const PriceTags({super.key, required this.listings, required this.onReserve});
  final List<Listing> listings;
  final ValueChanged<Listing> onReserve;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final l in listings)
            Padding(padding: const EdgeInsets.only(bottom: 14), child: PriceTag(listing: l, onReserve: onReserve)),
        ],
      );
}
