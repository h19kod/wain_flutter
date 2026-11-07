import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wain/api.dart';
import 'package:wain/reserve.dart';
import 'package:wain/track.dart';
import 'package:wain/widgets.dart';

import 'helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final listing = Listing.fromJson(listingJson(id: 10, price: 12000, available: 3));

  /// A page with one button that opens the sheet and shows what it returned.
  Widget opener(WainApi api) => Builder(
        builder: (context) {
          String? code;
          return StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Column(children: [
                TextButton(
                  onPressed: () async {
                    final made = await showReserveSheet(context, api: api, listing: listing, partName: 'بمب غسالة');
                    setState(() => code = made);
                  },
                  child: const Text('open'),
                ),
                Text('code:${code ?? '-'}'),
              ]),
            ),
          );
        },
      );

  testWidgets('the reserve sheet books the part and returns the code', (tester) async {
    late http.Request sent;
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((request) async {
        sent = request;
        return json(reservationJson(), 201);
      }),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(opener(api)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('احجز بمب غسالة'), findsOneWidget);
    expect(find.text('من محل الأمانة، الكرادة. السعر ١٢٬٠٠٠ د.ع للوحدة، وتدفع بالمحل.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reserve-name')), 'علي');
    await tester.enterText(find.byKey(const Key('reserve-phone')), '0770 123 4567');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('٢').last);
    await tester.pumpAndSettle();
    expect(find.text('احجز بـ ٢٤٬٠٠٠ د.ع'), findsOneWidget);

    await tester.tap(find.text('احجز بـ ٢٤٬٠٠٠ د.ع'));
    await tester.pumpAndSettle();

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://wain.test/api/reservations');
    expect(jsonDecode(sent.body), {
      'inventory': 10,
      'quantity': 2,
      'customer_name': 'علي',
      'customer_phone': '0770 123 4567',
    });
    expect(find.text('code:K7Q2MX'), findsOneWidget);
    expect(await LocalStore.lastPhone(), '0770 123 4567');
    expect(await LocalStore.recent(), ['reservation:K7Q2MX|بمب غسالة']);
  });

  testWidgets('the reserve sheet shows the server field errors and stays open', (tester) async {
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((_) async => json({'customer_phone': ['اكتب رقم موبايل عراقي صحيح.']}, 400)),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(opener(api)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('reserve-name')), 'علي');
    await tester.enterText(find.byKey(const Key('reserve-phone')), '123');
    await tester.tap(find.text('احجز بـ ١٢٬٠٠٠ د.ع'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب رقم موبايل عراقي صحيح.'), findsOneWidget);
    expect(find.text('code:-'), findsOneWidget);
  });

  testWidgets('the sheet will not send without a name', (tester) async {
    var calls = 0;
    final api = WainApi(baseUrl: 'http://wain.test', client: MockClient((_) async {
        calls++;
        return json({}, 500);
      }));
    tallScreen(tester);
    await tester.pumpWidget(app(opener(api)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احجز بـ ١٢٬٠٠٠ د.ع'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('tracking shows the stamp, code and amount, and cancels with the phone', (tester) async {
    final requests = <http.Request>[];
    final api = WainApi(
      baseUrl: 'http://wain.test',
      client: MockClient((request) async {
        requests.add(request);
        return request.method == 'GET'
            ? json(reservationJson())
            : json(reservationJson(status: 'cancelled'));
      }),
    );
    tallScreen(tester);
    await tester.pumpWidget(app(TrackReservationScreen(api: api, code: 'K7Q2MX')));
    await tester.pumpAndSettle();

    expect(requests.single.url.path, '/api/reservations/K7Q2MX');
    expect(find.text('محجوزة'), findsOneWidget);
    expect(find.text('القطعة محجوزة إلك. روح للمحل قبل ما ينتهي الوقت، وورّيهم الرمز.'), findsOneWidget);
    expect(find.text('K7Q2MX'), findsOneWidget);
    expect(find.text('٢٤٬٠٠٠ د.ع (٢ × ١٢٬٠٠٠ د.ع)، تدفعه بالمحل'), findsOneWidget);
    expect(find.text('محجوزة لحد'), findsOneWidget);
    expect(find.text('هذا محل تجريبي. ماكو قطعة حقيقية محجوزة.'), findsOneWidget);

    await tester.tap(find.text('ألغِ الحجز'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('cancel-phone')), '07701234567');
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();

    expect(requests.last.url.path, '/api/reservations/K7Q2MX/cancel');
    expect(jsonDecode(requests.last.body), {'customer_phone': '07701234567'});
    expect(find.text('ملغية'), findsOneWidget);
    expect(find.text('محجوزة لحد'), findsNothing);
    expect(find.text('ألغِ الحجز'), findsNothing);
    await tester.pumpWidget(const SizedBox()); // stops the refresh timer
  });

  testWidgets('an unknown code says so', (tester) async {
    final api = WainApi(baseUrl: 'http://wain.test', client: MockClient((_) async => json({'detail': 'Not found.'}, 404)));
    await tester.pumpWidget(app(TrackReservationScreen(api: api, code: 'NOPE00')));
    await tester.pumpAndSettle();
    expect(find.text('ما لكينا حجز بهذا الرمز.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
