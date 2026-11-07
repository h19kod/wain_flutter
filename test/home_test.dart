import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wain/api.dart';
import 'package:wain/home.dart';
import 'package:wain/state.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final metaJson = {
    'categories': [],
    'areas': [
      {'name': 'الكرادة', 'lat': 33.30, 'lng': 44.42},
    ],
    'shops': 3,
    'demo': false,
  };

  testWidgets('a typed code that is not a booking opens the matching request', (tester) async {
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((r) async => switch (r.url.path) {
            '/api/meta' => json(metaJson),
            '/api/reservations/RQ55AA' => json({'detail': 'Not found.'}, 404),
            '/api/requests/RQ55AA' => json({'code': 'RQ55AA', 'description': 'كمبروسر ثلاجة', 'status': 'open', 'offers': []}),
            _ => json({}, 500),
          }),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(HomeScreen(state: AppState(api), locate: () async => null)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('track-code')), 'rq55aa');
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    expect(find.text('طلب مفتوح'), findsOneWidget);
    expect(find.text('كمبروسر ثلاجة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stops the request page's refresh timer
  });

  testWidgets('an unknown code says nothing matched', (tester) async {
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((r) async => r.url.path == '/api/meta' ? json(metaJson) : json({'detail': 'Not found.'}, 404)),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(HomeScreen(state: AppState(api), locate: () async => null)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('track-code')), 'NOPE00');
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    expect(find.text('ما لكينا حجز أو طلب بهذا الرمز.'), findsOneWidget);
  });

  testWidgets('a picked area is sent as the search origin instead of GPS', (tester) async {
    Uri? searched;
    var askedGps = false;
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((r) async {
        if (r.url.path == '/api/meta') return json(metaJson);
        searched = r.url;
        return json({'results': []});
      }),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(HomeScreen(
      state: AppState(api),
      locate: () async {
        askedGps = true;
        return null;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قريب من موقعي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكرادة'));
    await tester.pumpAndSettle();
    expect(find.text('قريب من الكرادة'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-text')), 'بمب');
    await tester.tap(find.text('دوّر'));
    await tester.pumpAndSettle();

    expect(searched?.queryParameters, {'q': 'بمب', 'lat': '33.3', 'lng': '44.42'});
    expect(askedGps, isFalse);
    expect(find.text('ما لكينا قطعة باسم «بمب»'), findsOneWidget);
  });
}
