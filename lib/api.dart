import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The dev server started by WAIN/run.sh, as the Android emulator sees it.
/// Override with --dart-define=WAIN_API=http://192.168.1.20:8000 for a phone.
const defaultBaseUrl = String.fromEnvironment('WAIN_API', defaultValue: 'http://10.0.2.2:8000');

class Category {
  Category({required this.id, required this.nameAr, required this.nameEn, required this.slug});
  factory Category.fromJson(Map<String, dynamic> j) =>
      Category(id: j['id'] as int, nameAr: j['name_ar'] as String, nameEn: j['name_en'] as String, slug: j['slug'] as String);
  final int id;
  final String nameAr;
  final String nameEn;
  final String slug;
}

class Part {
  Part({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.category,
    this.description = '',
    this.partNumber = '',
    this.howToCheck = '',
    this.image,
    this.isIllustration = false,
  });
  factory Part.fromJson(Map<String, dynamic> j) => Part(
        id: j['id'] as int,
        nameAr: j['name_ar'] as String,
        nameEn: j['name_en'] as String? ?? '',
        description: j['description'] as String? ?? '',
        partNumber: j['part_number'] as String? ?? '',
        howToCheck: j['how_to_check'] as String? ?? '',
        category: Category.fromJson(j['category'] as Map<String, dynamic>),
        image: j['image'] as String?,
        isIllustration: j['is_illustration'] as bool? ?? false,
      );
  final int id;
  final String nameAr;
  final String nameEn;
  final String description;
  final String partNumber;
  final String howToCheck;
  final Category category;
  final String? image;
  final bool isIllustration;
}

class Shop {
  Shop({
    required this.id,
    required this.name,
    required this.area,
    this.address = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.isDemo = false,
  });
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'] as int,
        name: j['name'] as String,
        area: j['area'] as String? ?? '',
        address: j['address'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        isDemo: j['is_demo'] as bool? ?? false,
      );
  final int id;
  final String name;
  final String area;
  final String address;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isDemo;
}

class Listing {
  Listing({
    required this.id,
    required this.condition,
    required this.priceIqd,
    required this.available,
    required this.lastConfirmedAt,
    required this.shop,
    this.isStale = false,
    this.distanceKm,
  });
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as int,
        condition: j['condition'] as String,
        priceIqd: j['price_iqd'] as int,
        available: j['available'] as int,
        lastConfirmedAt: DateTime.parse(j['last_confirmed_at'] as String),
        isStale: j['is_stale'] as bool? ?? false,
        shop: Shop.fromJson(j['shop'] as Map<String, dynamic>),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
      );
  final int id;
  final String condition;
  final int priceIqd;
  final int available;
  final DateTime lastConfirmedAt;
  final bool isStale;
  final Shop shop;
  final double? distanceKm;
}

class Candidate {
  Candidate({required this.part, required this.listings});
  factory Candidate.fromJson(Map<String, dynamic> j) => Candidate(
        part: Part.fromJson(j['part'] as Map<String, dynamic>),
        listings: [for (final l in j['listings'] as List) Listing.fromJson(l as Map<String, dynamic>)],
      );
  final Part part;
  final List<Listing> listings;
}

enum SearchMode { image, text }

class SearchResult {
  SearchResult({required this.mode, required this.candidates, this.confidence, this.query, this.photo});
  final SearchMode mode;
  final List<Candidate> candidates;

  /// "high", "medium" or "low"; only image searches have one.
  final String? confidence;
  final String? query;
  final Uint8List? photo;

  bool get unsure => mode == SearchMode.image && confidence != 'high';
}

class Area {
  Area(this.name, this.lat, this.lng);
  final String name;
  final double lat;
  final double lng;
}

class Meta {
  Meta({required this.areas, required this.shops, required this.demo});
  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        areas: [
          for (final a in j['areas'] as List)
            Area(a['name'] as String, (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble()),
        ],
        shops: j['shops'] as int? ?? 0,
        demo: j['demo'] as bool? ?? false,
      );
  final List<Area> areas;
  final int shops;
  final bool demo;
}

class Reservation {
  Reservation({
    required this.code,
    required this.status,
    required this.quantity,
    required this.unitPriceIqd,
    required this.totalIqd,
    required this.partName,
    required this.condition,
    required this.shop,
    required this.expiresAt,
  });
  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
        code: j['code'] as String,
        status: j['status'] as String,
        quantity: j['quantity'] as int,
        unitPriceIqd: j['unit_price_iqd'] as int,
        totalIqd: j['total_iqd'] as int,
        partName: j['part_name'] as String,
        condition: j['condition'] as String? ?? '',
        shop: Shop.fromJson(j['shop'] as Map<String, dynamic>),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
  final String code;

  /// held, confirmed, completed, cancelled or expired.
  final String status;
  final int quantity;
  final int unitPriceIqd;
  final int totalIqd;
  final String partName;
  final String condition;
  final Shop shop;
  final DateTime expiresAt;

  bool get isOpen => status == 'held' || status == 'confirmed';
}

class Offer {
  Offer({required this.id, required this.shop, required this.priceIqd, this.note = ''});
  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as int,
        shop: Shop.fromJson(j['shop'] as Map<String, dynamic>),
        priceIqd: j['price_iqd'] as int,
        note: j['note'] as String? ?? '',
      );
  final int id;
  final Shop shop;
  final int priceIqd;
  final String note;
}

class PartRequest {
  PartRequest({required this.code, required this.description, required this.status, required this.offers});
  factory PartRequest.fromJson(Map<String, dynamic> j) => PartRequest(
        code: j['code'] as String,
        description: j['description'] as String,
        status: j['status'] as String? ?? '',
        offers: [for (final o in j['offers'] as List) Offer.fromJson(o as Map<String, dynamic>)],
      );
  final String code;
  final String description;
  final String status;
  final List<Offer> offers;
}

class ApiError implements Exception {
  ApiError(this.message, [this.fields = const {}, this.status = 0]);
  final String message;
  final Map<String, String> fields;
  final int status;

  /// Field errors when the server gave any, otherwise the message under "detail".
  Map<String, String> get asFields => fields.isNotEmpty ? fields : {'detail': message};

  @override
  String toString() => message;
}

class Origin {
  const Origin(this.lat, this.lng);
  final double lat;
  final double lng;
}

class WainApi {
  WainApi({String baseUrl = defaultBaseUrl, http.Client? client})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// The server sends media as "/media/…"; images need the full address.
  String? media(String? path) {
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http') ? path : '$baseUrl$path';
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ApiError('ما كدرنا نوصل للخادم. تأكد من الإنترنت وحاول مرة ثانية.');
    }
    Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 400) {
      final fields = <String, String>{};
      if (data is Map) {
        data.forEach((key, value) {
          fields['$key'] = value is List ? value.map((v) => '$v').join(' ') : '$value';
        });
      }
      final message = fields['detail'] ?? (fields.isNotEmpty ? fields.values.first : 'صار خطأ. حاول مرة ثانية.');
      throw ApiError(message, fields, response.statusCode);
    }
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _sendMultipart(http.MultipartRequest request) =>
      _send(() async => http.Response.fromStream(await _client.send(request)));

  Map<String, String> _origin(Origin? origin) =>
      origin == null ? {} : {'lat': '${origin.lat}', 'lng': '${origin.lng}'};

  Future<Meta> meta() async => Meta.fromJson(await _send(() => _client.get(_uri('/meta'))));

  Future<SearchResult> searchImage(Uint8List photo, {Origin? origin}) async {
    final request = http.MultipartRequest('POST', _uri('/search/image'))
      ..fields.addAll(_origin(origin))
      ..files.add(http.MultipartFile.fromBytes('image', photo, filename: 'photo.jpg'));
    final data = await _sendMultipart(request);
    return SearchResult(
      mode: SearchMode.image,
      confidence: data['confidence'] as String?,
      candidates: [for (final c in data['candidates'] as List) Candidate.fromJson(c as Map<String, dynamic>)],
      photo: photo,
    );
  }

  Future<SearchResult> searchText(String query, {Origin? origin}) async {
    final data = await _send(() => _client.get(_uri('/search/text', {'q': query, ..._origin(origin)})));
    return SearchResult(
      mode: SearchMode.text,
      query: query,
      candidates: [for (final c in data['results'] as List) Candidate.fromJson(c as Map<String, dynamic>)],
    );
  }

  Future<Uint8List> download(String url) async {
    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {
      // Falls through to the same message as any other failed call.
    }
    throw ApiError('ما كدرنا نجيب الصورة. حاول مرة ثانية.');
  }

  Future<Reservation> reserve({
    required int inventory,
    required int quantity,
    required String name,
    required String phone,
  }) async {
    final body = jsonEncode({'inventory': inventory, 'quantity': quantity, 'customer_name': name, 'customer_phone': phone});
    return Reservation.fromJson(
      await _send(() => _client.post(_uri('/reservations'), headers: {'Content-Type': 'application/json'}, body: body)),
    );
  }

  Future<Reservation> reservation(String code) async =>
      Reservation.fromJson(await _send(() => _client.get(_uri('/reservations/$code'))));

  Future<Reservation> cancelReservation(String code, String phone) async => Reservation.fromJson(
        await _send(() => _client.post(
              _uri('/reservations/$code/cancel'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'customer_phone': phone}),
            )),
      );

  Future<PartRequest> requestPart({
    required String description,
    required String area,
    required String name,
    required String phone,
    int? suggestedPart,
    Uint8List? photo,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/requests'))
      ..fields.addAll({
        'description': description,
        'area': area,
        'customer_name': name,
        'customer_phone': phone,
        if (suggestedPart != null) 'suggested_part': '$suggestedPart',
      });
    if (photo != null) request.files.add(http.MultipartFile.fromBytes('image', photo, filename: 'photo.jpg'));
    return PartRequest.fromJson(await _sendMultipart(request));
  }

  Future<PartRequest> partRequest(String code) async =>
      PartRequest.fromJson(await _send(() => _client.get(_uri('/requests/$code'))));
}
