import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

class Alert extends StatelessWidget {
  const Alert(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.wain;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: WainColors.mix(c.stamp, 0.14, c.card),
          border: BorderDirectional(start: BorderSide(color: c.stamp, width: 4)),
        ),
        child: Text(message),
      ),
    );
  }
}

class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(message!, style: TextStyle(color: context.wain.stamp, fontSize: 14)),
        );
}

class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.small = false});
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: context.wain.ink2, fontSize: small ? 14 : null));
}

class Labelled extends StatelessWidget {
  const Labelled({super.key, required this.label, required this.child, this.error});
  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          child,
          FieldError(error),
        ],
      );
}

/// An image from the server that quietly shows a grey square when it cannot load.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, required this.size, this.radius = 4});
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final blank = Container(width: size, height: size, color: context.wain.rule);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? blank
          : Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => blank),
    );
  }
}

Future<void> openUri(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!opened) messenger.showSnackBar(const SnackBar(content: Text('ما كدرنا نفتح هذا الرابط على موبايلك.')));
}

Future<void> callShop(BuildContext context, String phone) => openUri(context, Uri(scheme: 'tel', path: phone));

/// What the app remembers on the phone: the last phone number and recent codes.
class LocalStore {
  static const _phone = 'wain_last_phone';
  static const _codes = 'wain_recent';

  static Future<String> lastPhone() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_phone) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> rememberPhone(String phone) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_phone, phone);
    } catch (_) {
      // Optional convenience; the forms still work without it.
    }
  }

  /// Entries look like "reservation:AB12CD|بمب غسالة".
  static Future<List<String>> recent() async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_codes) ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> forget(String entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_codes, (prefs.getStringList(_codes) ?? []).where((e) => e != entry).toList());
    } catch (_) {
      // Optional convenience.
    }
  }

  static Future<String?> read(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      return null;
    }
  }

  /// Saves [value] under [key], or removes the key when [value] is null.
  static Future<void> write(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value == null ? await prefs.remove(key) : await prefs.setString(key, value);
    } catch (_) {
      // Settings fall back to their defaults.
    }
  }

  static const shopToken = 'wain_shop_token';
  static const server = 'wain_server';
  static const themeMode = 'wain_theme';

  /// The area the customer picked instead of GPS, or "gps".
  static const area = 'wain_area';

  static Future<void> remember(String kind, String code, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entry = '$kind:$code|$title';
      final list = (prefs.getStringList(_codes) ?? []).where((e) => !e.startsWith('$kind:$code|')).toList();
      await prefs.setStringList(_codes, [entry, ...list].take(8).toList());
    } catch (_) {
      // Optional convenience.
    }
  }
}
