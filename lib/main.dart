import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WainApp(state: await AppState.load()));
}

class WainApp extends StatelessWidget {
  const WainApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'وين ألكاه؟',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', 'IQ'),
          supportedLocales: const [Locale('ar', 'IQ'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          // A new server means a fresh home screen with its own catalogue.
          home: HomeScreen(key: ValueKey(state.api.baseUrl), state: state),
        ),
      );
}
