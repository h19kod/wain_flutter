import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wain/api.dart';
import 'package:wain/requests.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'wain_last_phone': '07701234567'}));

  testWidgets('the rare-part request sends the form and returns the code', (tester) async {
    late http.BaseRequest sent;
    late String body;
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((request) async {
        sent = request;
        body = request.body;
        return json({'code': 'RQ55AA', 'description': 'كمبروسر ثلاجة', 'status': 'open', 'offers': []}, 201);
      }),
    );
    final meta = Meta(areas: [Area('الكرادة', 33.3, 44.4)], shops: 3, demo: true);
    String? code;
    tallScreen(tester);
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => code = await Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => RequestScreen(api: api, meta: meta, query: 'كمبروسر ثلاجة'),
        )),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('كمبروسر ثلاجة'), findsOneWidget);
    expect(find.text('07701234567'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'علي');
    await tester.tap(find.text('أرسل الطلب'));
    await tester.pumpAndSettle();

    expect(sent.url.path, '/api/requests');
    expect(sent.headers['content-type'], startsWith('multipart/form-data'));
    for (final field in ['كمبروسر ثلاجة', 'علي', '07701234567']) {
      expect(body, contains(field));
    }
    expect(code, 'RQ55AA');
  });

  testWidgets('tracking a request lists the offers', (tester) async {
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((_) async => json({
            'code': 'RQ55AA',
            'description': 'كمبروسر ثلاجة',
            'status': 'open',
            'offers': [
              {'id': 1, 'shop': shopJson(), 'price_iqd': 85000, 'note': 'مستعمل نظيف', 'created_at': now.toIso8601String()},
            ],
          })),
    );
    await tester.pumpWidget(app(TrackRequestScreen(api: api, code: 'RQ55AA')));
    await tester.pumpAndSettle();
    expect(find.text('طلب مفتوح'), findsOneWidget);
    expect(find.text('٨٥٬٠٠٠ د.ع'), findsOneWidget);
    expect(find.text('محل الأمانة، الكرادة'), findsOneWidget);
    expect(find.text('مستعمل نظيف'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
