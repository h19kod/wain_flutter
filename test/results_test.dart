import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wain/api.dart';
import 'package:wain/results.dart';

import 'helpers.dart';

void main() {
  final api = WainApi(baseUrl: 'http://wain.test');

  Future<void> show(
    WidgetTester tester,
    SearchResult result, {
    void Function(Listing, String)? onReserve,
    ValueChanged<Part?>? onAsk,
  }) async {
    tallScreen(tester);
    await tester.pumpWidget(app(Scaffold(
      body: SingleChildScrollView(
        child: ResultsView(
          result: result,
          api: api,
          onReserve: onReserve ?? (_, _) {},
          onAsk: onAsk ?? (_) {},
        ),
      ),
    )));
  }

  final pump = candidate(partJson(check: 'عدد الأرجل وشكل الفتحة'), [
    listingJson(id: 10, price: 12000, distance: 2.5),
    listingJson(id: 11, price: 9500, condition: 'used', stale: true, shop: shopJson(id: 2, name: 'محل النور', area: 'الشورجة')),
  ]);
  final motor = candidate(partJson(id: 2, ar: 'ماطور غسالة', en: 'Washer motor'), []);

  testWidgets('a sure photo match names the part and lists shops as price tags', (tester) async {
    await show(tester, SearchResult(mode: SearchMode.image, confidence: 'high', candidates: [pump]));

    expect(find.text('نعتقد قطعتك هي:'), findsOneWidget);
    expect(find.text('بمب غسالة'), findsOneWidget);
    expect(find.text('Washer drain pump · غسالات'), findsOneWidget);
    expect(find.text('٢ محلات عندهم هاي القطعة'), findsOneWidget);
    expect(find.text('١٢٬٠٠٠ د.ع'), findsOneWidget);
    expect(find.text('٩٬٥٠٠ د.ع'), findsOneWidget);
    expect(find.text('مستعمل'), findsOneWidget);
    expect(find.text('الكرادة · يبعد ٢٫٥ كم'), findsOneWidget);
    expect(find.text('المحل أكد التوفر قبل ٣ ساعة'), findsOneWidget);
    expect(find.text('ما تأكد التوفر من أسبوع أو أكثر. اتصل قبل لا تروح.'), findsOneWidget);
    expect(find.textContaining('عدد الأرجل وشكل الفتحة', findRichText: true), findsOneWidget);
    expect(find.text('الصور رسوم توضيحية، مو صور القطعة الحقيقية.'), findsOneWidget);
  });

  testWidgets('an unsure match asks which look-alike it is and switches shops on pick', (tester) async {
    await show(tester, SearchResult(mode: SearchMode.image, confidence: 'medium', candidates: [pump, motor]));

    expect(find.text('مو متأكدين. أي وحدة تشبه قطعتك؟'), findsOneWidget);
    expect(find.text('٢ محلات عندهم هاي القطعة'), findsOneWidget);

    await tester.tap(find.text('ماطور غسالة'));
    await tester.pump();

    expect(find.text('ماطور غسالة'), findsNWidgets(2));
    expect(find.text('ماكو محل عنده هاي القطعة هسه'), findsOneWidget);
    expect(find.text('١٢٬٠٠٠ د.ع'), findsNothing);
  });

  testWidgets('a text search asks if this is the part', (tester) async {
    await show(tester, SearchResult(mode: SearchMode.text, query: 'بمب', candidates: [pump]));
    expect(find.text('هاي اللي تدور عليها؟'), findsOneWidget);
  });

  testWidgets('reserving a tag hands over the listing and part name', (tester) async {
    Listing? reserved;
    String? name;
    await show(
      tester,
      SearchResult(mode: SearchMode.image, confidence: 'high', candidates: [pump]),
      onReserve: (l, n) => (reserved, name) = (l, n),
    );

    await tester.tap(find.text('احجزها').last);
    expect(reserved?.id, 11);
    expect(name, 'بمب غسالة');
  });

  testWidgets('nothing found offers the rare-part request', (tester) async {
    var asked = false;
    await show(
      tester,
      SearchResult(mode: SearchMode.text, query: 'كمبروسر ثلاجة', candidates: []),
      onAsk: (_) => asked = true,
    );

    expect(find.text('ما لكينا قطعة باسم «كمبروسر ثلاجة»'), findsOneWidget);
    await tester.tap(find.text('اطلبها من المحلات'));
    expect(asked, isTrue);
  });

  testWidgets('the request button suggests the part on screen', (tester) async {
    Part? suggested;
    await show(
      tester,
      SearchResult(mode: SearchMode.image, confidence: 'low', candidates: [pump, motor]),
      onAsk: (p) => suggested = p,
    );
    await tester.tap(find.text('ما لكيت قطعتي؟ اطلبها من المحلات'));
    expect(suggested?.id, 1);
  });
}
