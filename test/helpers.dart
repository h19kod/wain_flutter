import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wain/api.dart';
import 'package:wain/theme.dart';

Widget app(Widget child) => MaterialApp(
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      home: child,
    );

/// A tall phone so long result lists fit without scrolling.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4800);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
}

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

final now = DateTime.now();

Map<String, dynamic> shopJson({int id = 1, String name = 'محل الأمانة', String area = 'الكرادة', bool demo = true}) => {
      'id': id,
      'name': name,
      'area': area,
      'address': 'شارع ٦٢',
      'phone': '07701234567',
      'latitude': 33.3,
      'longitude': 44.4,
      'is_demo': demo,
    };

Map<String, dynamic> listingJson({
  int id = 10,
  int price = 12000,
  String condition = 'new',
  int available = 3,
  bool stale = false,
  double? distance = 2.5,
  Map<String, dynamic>? shop,
}) =>
    {
      'id': id,
      'condition': condition,
      'price_iqd': price,
      'available': available,
      'last_confirmed_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
      'is_stale': stale,
      'shop': shop ?? shopJson(),
      'distance_km': distance,
    };

Map<String, dynamic> partJson({int id = 1, String ar = 'بمب غسالة', String en = 'Washer drain pump', String check = ''}) => {
      'id': id,
      'name_ar': ar,
      'name_en': en,
      'aliases': <String>[],
      'description': '',
      'part_number': '',
      'fits': <String>[],
      'how_to_check': check,
      'category': {'id': 1, 'name_ar': 'غسالات', 'name_en': 'Washers', 'slug': 'washers'},
      'image': null,
      'is_illustration': true,
    };

Candidate candidate(Map<String, dynamic> part, List<Map<String, dynamic>> listings) =>
    Candidate.fromJson({'part': part, 'listings': listings});

Map<String, dynamic> reservationJson({String status = 'held', int quantity = 2}) => {
      'code': 'K7Q2MX',
      'status': status,
      'quantity': quantity,
      'unit_price_iqd': 12000,
      'total_iqd': 12000 * quantity,
      'part_name': 'بمب غسالة',
      'condition': 'new',
      'shop': shopJson(),
      'expires_at': now.add(const Duration(hours: 3)).toIso8601String(),
      'created_at': now.toIso8601String(),
    };
