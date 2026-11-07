import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wain/api.dart';
import 'package:wain/shop.dart';
import 'package:wain/state.dart';
import 'package:wain/widgets.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final meta = Meta(areas: [Area('الكرادة', 33.3, 44.4)], shops: 3, demo: true);

  Map<String, dynamic> booking({String status = 'held'}) => {
        'id': 5,
        'code': 'K7Q2MX',
        'status': status,
        'quantity': 1,
        'unit_price_iqd': 12000,
        'commission_iqd': 600,
        'part_name': 'بمب غسالة',
        'condition': 'new',
        'customer_name': 'علي',
        'customer_phone': '07701234567',
        'expires_at': now.add(const Duration(hours: 3)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };

  /// A fake server for one shop. Returns every request it saw.
  (WainApi, List<http.Request>) server({bool expired = false}) {
    final seen = <http.Request>[];
    var status = 'held';
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((r) async {
        seen.add(r);
        final path = r.url.path.replaceFirst('/api', '');
        if (expired && path.startsWith('/shop')) return json({'detail': 'Invalid token.'}, 401);
        return switch ((r.method, path)) {
          ('POST', '/auth/login') => json({'token': 'tok123', 'shop': {}}),
          ('GET', '/shop/me') => json({
              'id': 1, 'name': 'محل الأمانة', 'area': 'الكرادة', 'plan': 'free',
              'is_verified': true, 'is_demo': true, 'item_limit': 25,
            }),
          ('GET', '/shop/stats') => json({
              'open_reservations': 1, 'completed_reservations': 4, 'commission_due_iqd': 2400,
              'items': 3, 'item_limit': 25, 'stale_items': 1,
            }),
          ('GET', '/shop/reservations') => json([booking(status: status)]),
          ('POST', '/shop/reservations/5/complete') => json(booking(status: status = 'completed')),
          ('GET', '/shop/inventory') => json([
              {
                'id': 7, 'part': 1, 'part_name': 'بمب غسالة', 'part_approved': true, 'condition': 'new',
                'price_iqd': 12000, 'quantity': 3, 'reserved': 1, 'available': 2,
                'last_confirmed_at': now.subtract(const Duration(days: 9)).toIso8601String(), 'is_stale': true,
              },
            ]),
          ('POST', '/shop/inventory/confirm') => json({'confirmed': 1}),
          ('GET', '/shop/requests') => json([]),
          ('GET', '/shop/demand') => json([]),
          _ => json({'detail': 'unexpected ${r.method} $path'}, 500),
        };
      }),
    );
    return (api, seen);
  }

  Future<AppState> signIn(WidgetTester tester, WainApi api) async {
    final state = AppState(api);
    tallScreen(tester);
    await tester.pumpWidget(app(ShopPortalScreen(state: state, meta: meta)));
    await tester.enterText(find.byKey(const Key('shop-username')), 'shop1');
    await tester.enterText(find.byKey(const Key('shop-password')), 'secret-pass');
    await tester.tap(find.text('ادخل'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('a shop owner signs in and sees stats and bookings', (tester) async {
    final (api, seen) = server();
    final state = await signIn(tester, api);

    expect(state.signedIn, isTrue);
    expect(await LocalStore.read(LocalStore.shopToken), 'tok123');
    expect(jsonDecode(seen.first.body), {'username': 'shop1', 'password': 'secret-pass'});
    expect(seen.firstWhere((r) => r.url.path == '/api/shop/me').headers['Authorization'], 'Token tok123');

    expect(find.text('محل الأمانة'), findsOneWidget);
    expect(find.text('٢٬٤٠٠ د.ع'), findsOneWidget);
    expect(find.text('١ صنف ما تأكدت منه من أسبوع. هذني ينزلن لآخر نتائج البحث.'), findsOneWidget);
    expect(find.text('بمب غسالة × ١'), findsOneWidget);
    expect(find.text('جديد'), findsOneWidget);
  });

  testWidgets('marking a booking collected posts the action and updates it', (tester) async {
    final (api, seen) = server();
    await signIn(tester, api);

    await tester.tap(find.text('الزبون استلمها'));
    await tester.pumpAndSettle();

    expect(seen.any((r) => r.method == 'POST' && r.url.path == '/api/shop/reservations/5/complete'), isTrue);
    expect(find.text('استلمها'), findsOneWidget);
    expect(find.text('الزبون استلمها'), findsNothing);
  });

  testWidgets('the stock tab lists items and confirms them all', (tester) async {
    final (api, seen) = server();
    await signIn(tester, api);

    await tester.tap(find.text('المخزون'));
    await tester.pumpAndSettle();
    expect(find.text('بمب غسالة'), findsOneWidget);
    expect(find.textContaining('ما تأكد من أسبوع'), findsOneWidget);

    await tester.tap(find.text('كل شي بالقائمة صحيح'));
    await tester.pumpAndSettle();
    expect(seen.any((r) => r.url.path == '/api/shop/inventory/confirm'), isTrue);
    expect(find.text('أكدت ١ صنف. الزبائن يشوفون إن المخزون محدّث.'), findsOneWidget);
  });

  testWidgets('a rejected token sends the owner back to the login form', (tester) async {
    final (api, _) = server(expired: true);
    api.token = 'old';
    final state = AppState(api);
    await tester.pumpWidget(app(ShopPortalScreen(state: state, meta: meta)));
    await tester.pumpAndSettle();

    expect(state.signedIn, isFalse);
    expect(find.text('دخول أصحاب المحلات'), findsOneWidget);
  });

  testWidgets('registering needs an area and a long password', (tester) async {
    final (api, seen) = server();
    tallScreen(tester);
    await tester.pumpWidget(app(ShopPortalScreen(state: AppState(api), meta: meta)));
    await tester.tap(find.text('ما عندك حساب؟ سجّل محلك'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('shop-password')), 'short');
    await tester.tap(find.text('سجّل المحل'));
    await tester.pump();

    expect(find.text('كلمة السر ٨ حروف أو أكثر.'), findsOneWidget);
    expect(find.text('اختار المنطقة.'), findsOneWidget);
    expect(seen, isEmpty);
  });
}
