import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'home.dart';
import 'theme.dart';

void main() => runApp(WainApp(api: WainApi()));

class WainApp extends StatelessWidget {
  const WainApp({super.key, required this.api});
  final WainApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'وين ألكاه؟',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'IQ'),
        supportedLocales: const [Locale('ar', 'IQ'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: HomeScreen(api: api),
      );
}
