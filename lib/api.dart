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
  Meta({required this.areas, required this.shops, required this.demo, this.categories = const []});
  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        categories: [for (final c in j['categories'] as List? ?? []) Category.fromJson(c as Map<String, dynamic>)],
        areas: [
          for (final a in j['areas'] as List)
            Area(a['name'] as String, (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble()),
        ],
        shops: j['shops'] as int? ?? 0,
        demo: j['demo'] as bool? ?? false,
      );
  final List<Area> areas;
  final List<Category> categories;
  final int shops;
  final bool demo;

  static final empty = Meta(areas: [], shops: 0, demo: false);
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
  WainApi({String baseUrl = defaultBaseUrl, http.Client? client, this.token})
      : baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// The shop owner's token, once they sign in. Customers never need one.
  String? token;

  /// Called when the server rejects the shop token, so the app can forget it.
  void Function()? onSignedOut;

  /// The server sends media as "/media/…"; images need the full address.
  String? media(String? path) {
    if (path == null || path.isEmpty) return null;
    return path.startsWith('http') ? path : '$baseUrl$path';
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api$path').replace(queryParameters: query);

  Map<String, String> _headers({bool auth = false, bool json = false}) => {
        if (auth && token != null) 'Authorization': 'Token $token',
        if (json) 'Content-Type': 'application/json',
      };

  Future<Object?> _send(Future<http.Response> Function() request, {bool auth = false}) async {
    http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 45));
    } catch (_) {
      throw ApiError('ما كدرنا نوصل للخادم. تأكد من الإنترنت وحاول مرة ثانية.');
    }
    if (response.statusCode == 204) return null;
    Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && auth) {
        token = null;
        onSignedOut?.call();
      }
      final fields = <String, String>{};
      if (data is Map) {
        data.forEach((key, value) {
          fields['$key'] = value is List ? value.map((v) => '$v').join(' ') : '$value';
        });
      }
      final message = fields['detail'] ?? (fields.isNotEmpty ? fields.values.first : 'صار خطأ. حاول مرة ثانية.');
      throw ApiError(message, fields, response.statusCode);
    }
    return data;
  }

  Future<Object?> _get(String path, {Map<String, String>? query, bool auth = false}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers(auth: auth)), auth: auth);

  Future<Object?> _post(String path, [Object? body, bool auth = false]) => _send(
        () => _client.post(_uri(path), headers: _headers(auth: auth, json: true), body: jsonEncode(body ?? {})),
        auth: auth,
      );

  Future<Object?> _multipart(String path, Map<String, String> fields, {Uint8List? image, bool auth = false}) {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers(auth: auth))
      ..fields.addAll(fields);
    if (image != null) request.files.add(http.MultipartFile.fromBytes('image', image, filename: 'photo.jpg'));
    return _send(() async => http.Response.fromStream(await _client.send(request)), auth: auth);
  }

  Map<String, String> _origin(Origin? origin) =>
      origin == null ? {} : {'lat': '${origin.lat}', 'lng': '${origin.lng}'};

  static Map<String, dynamic> _map(Object? data) => data is Map<String, dynamic> ? data : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(Object? data) =>
      data is List ? data.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];

  // Customers -----------------------------------------------------------------------

  Future<Meta> meta() async => Meta.fromJson(_map(await _get('/meta')));

  Future<SearchResult> searchImage(Uint8List photo, {Origin? origin}) async {
    final data = _map(await _multipart('/search/image', _origin(origin), image: photo));
    return SearchResult(
      mode: SearchMode.image,
      confidence: data['confidence'] as String?,
      candidates: [for (final c in _list(data['candidates'])) Candidate.fromJson(c)],
      photo: photo,
    );
  }

  Future<SearchResult> searchText(String query, {Origin? origin}) async {
    final data = _map(await _get('/search/text', query: {'q': query, ..._origin(origin)}));
    return SearchResult(
      mode: SearchMode.text,
      query: query,
      candidates: [for (final c in _list(data['results'])) Candidate.fromJson(c)],
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
  }) async =>
      Reservation.fromJson(_map(await _post('/reservations', {
        'inventory': inventory,
        'quantity': quantity,
        'customer_name': name,
        'customer_phone': phone,
      })));

  Future<Reservation> reservation(String code) async =>
      Reservation.fromJson(_map(await _get('/reservations/${Uri.encodeComponent(code)}')));

  Future<Reservation> cancelReservation(String code, String phone) async => Reservation.fromJson(
        _map(await _post('/reservations/${Uri.encodeComponent(code)}/cancel', {'customer_phone': phone})),
      );

  Future<PartRequest> requestPart({
    required String description,
    required String area,
    required String name,
    required String phone,
    int? suggestedPart,
    Uint8List? photo,
  }) async =>
      PartRequest.fromJson(_map(await _multipart(
        '/requests',
        {
          'description': description,
          'area': area,
          'customer_name': name,
          'customer_phone': phone,
          if (suggestedPart != null) 'suggested_part': '$suggestedPart',
        },
        image: photo,
      )));

  Future<PartRequest> partRequest(String code) async =>
      PartRequest.fromJson(_map(await _get('/requests/${Uri.encodeComponent(code)}')));

  // Shop owners ---------------------------------------------------------------------

  Future<String> login(String username, String password) async {
    final data = _map(await _post('/auth/login', {'username': username, 'password': password}));
    return token = data['token'] as String;
  }

  Future<String> register(Map<String, String> fields) async {
    final data = _map(await _post('/auth/register', fields));
    return token = data['token'] as String;
  }

  Future<ShopMe> me() async => ShopMe.fromJson(_map(await _get('/shop/me', auth: true)));

  Future<ShopStats> stats() async => ShopStats.fromJson(_map(await _get('/shop/stats', auth: true)));

  Future<List<Booking>> bookings() async =>
      [for (final b in _list(await _get('/shop/reservations', auth: true))) Booking.fromJson(b)];

  /// [action] is confirm, complete or cancel.
  Future<Booking> bookingAction(int id, String action) async =>
      Booking.fromJson(_map(await _post('/shop/reservations/$id/$action', null, true)));

  Future<List<StockItem>> inventory() async =>
      [for (final i in _list(await _get('/shop/inventory', auth: true))) StockItem.fromJson(i)];

  Future<StockItem> addStock({required int part, required int price, required int quantity, required String condition}) async =>
      StockItem.fromJson(_map(await _post(
        '/shop/inventory',
        {'part': part, 'price_iqd': price, 'quantity': quantity, 'condition': condition},
        true,
      )));

  Future<StockItem> updateStock(int id, {int? price, int? quantity}) async => StockItem.fromJson(_map(await _send(
        () => _client.patch(
          _uri('/shop/inventory/$id'),
          headers: _headers(auth: true, json: true),
          body: jsonEncode({'price_iqd': ?price, 'quantity': ?quantity}),
        ),
        auth: true,
      )));

  Future<void> removeStock(int id) =>
      _send(() => _client.delete(_uri('/shop/inventory/$id'), headers: _headers(auth: true)), auth: true);

  Future<int> confirmStock() async =>
      (_map(await _post('/shop/inventory/confirm', null, true))['confirmed'] as int?) ?? 0;

  Future<List<Part>> pickParts(String query) async => [
        for (final p in _list(await _get('/shop/parts', query: {'q': query}, auth: true))) Part.fromJson(p),
      ];

  Future<Part> proposePart({required String name, required int category, required Uint8List photo}) async =>
      Part.fromJson(_map(await _multipart(
        '/shop/parts/propose',
        {'name_ar': name, 'category': '$category'},
        image: photo,
        auth: true,
      )));

  Future<List<OpenRequest>> openRequests() async =>
      [for (final r in _list(await _get('/shop/requests', auth: true))) OpenRequest.fromJson(r)];

  Future<void> sendOffer(int requestId, {required int price, String note = ''}) =>
      _post('/shop/requests/$requestId/offers', {'price_iqd': price, 'note': note}, true);

  Future<List<Demand>> demand() async =>
      [for (final d in _list(await _get('/shop/demand', auth: true))) Demand.fromJson(d)];
}

// Shop-owner models ---------------------------------------------------------------

class ShopMe {
  ShopMe({
    required this.id,
    required this.name,
    required this.area,
    required this.plan,
    required this.isVerified,
    required this.isDemo,
    required this.itemLimit,
  });
  factory ShopMe.fromJson(Map<String, dynamic> j) => ShopMe(
        id: j['id'] as int,
        name: j['name'] as String,
        area: j['area'] as String? ?? '',
        plan: j['plan'] as String? ?? 'free',
        isVerified: j['is_verified'] as bool? ?? false,
        isDemo: j['is_demo'] as bool? ?? false,
        itemLimit: j['item_limit'] as int? ?? 0,
      );
  final int id;
  final String name;
  final String area;
  final String plan;
  final bool isVerified;
  final bool isDemo;
  final int itemLimit;

  String get planName => switch (plan) { 'basic' => 'الأساسية', 'pro' => 'الاحترافية', _ => 'المجانية' };
}

class ShopStats {
  ShopStats({
    required this.openReservations,
    required this.completedReservations,
    required this.commissionDueIqd,
    required this.items,
    required this.itemLimit,
    required this.staleItems,
  });
  factory ShopStats.fromJson(Map<String, dynamic> j) => ShopStats(
        openReservations: j['open_reservations'] as int? ?? 0,
        completedReservations: j['completed_reservations'] as int? ?? 0,
        commissionDueIqd: j['commission_due_iqd'] as int? ?? 0,
        items: j['items'] as int? ?? 0,
        itemLimit: j['item_limit'] as int? ?? 0,
        staleItems: j['stale_items'] as int? ?? 0,
      );
  final int openReservations;
  final int completedReservations;
  final int commissionDueIqd;
  final int items;
  final int itemLimit;
  final int staleItems;
}

class Booking {
  Booking({
    required this.id,
    required this.code,
    required this.status,
    required this.quantity,
    required this.unitPriceIqd,
    required this.commissionIqd,
    required this.partName,
    required this.condition,
    required this.customerName,
    required this.customerPhone,
    required this.expiresAt,
  });
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as int,
        code: j['code'] as String,
        status: j['status'] as String,
        quantity: j['quantity'] as int,
        unitPriceIqd: j['unit_price_iqd'] as int,
        commissionIqd: j['commission_iqd'] as int? ?? 0,
        partName: j['part_name'] as String,
        condition: j['condition'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '',
        customerPhone: j['customer_phone'] as String? ?? '',
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
  final int id;
  final String code;
  final String status;
  final int quantity;
  final int unitPriceIqd;
  final int commissionIqd;
  final String partName;
  final String condition;
  final String customerName;
  final String customerPhone;
  final DateTime expiresAt;

  bool get isOpen => status == 'held' || status == 'confirmed';
}

class StockItem {
  StockItem({
    required this.id,
    required this.part,
    required this.partName,
    required this.partApproved,
    required this.condition,
    required this.priceIqd,
    required this.quantity,
    required this.reserved,
    required this.available,
    required this.lastConfirmedAt,
    required this.isStale,
  });
  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
        id: j['id'] as int,
        part: j['part'] as int,
        partName: j['part_name'] as String? ?? '',
        partApproved: j['part_approved'] as bool? ?? true,
        condition: j['condition'] as String? ?? 'new',
        priceIqd: j['price_iqd'] as int,
        quantity: j['quantity'] as int,
        reserved: j['reserved'] as int? ?? 0,
        available: j['available'] as int? ?? 0,
        lastConfirmedAt: DateTime.parse(j['last_confirmed_at'] as String),
        isStale: j['is_stale'] as bool? ?? false,
      );
  final int id;
  final int part;
  final String partName;
  final bool partApproved;
  final String condition;
  final int priceIqd;
  final int quantity;
  final int reserved;
  final int available;
  final DateTime lastConfirmedAt;
  final bool isStale;
}

class OpenRequest {
  OpenRequest({required this.id, required this.description, required this.area, required this.createdAt, this.image, this.myOfferIqd});
  factory OpenRequest.fromJson(Map<String, dynamic> j) => OpenRequest(
        id: j['id'] as int,
        description: j['description'] as String,
        area: j['area'] as String? ?? '',
        image: j['image'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        myOfferIqd: (j['my_offer'] as Map<String, dynamic>?)?['price_iqd'] as int?,
      );
  final int id;
  final String description;
  final String area;
  final String? image;
  final DateTime createdAt;
  final int? myOfferIqd;
}

class Demand {
  Demand({required this.part, required this.name, required this.searches});
  factory Demand.fromJson(Map<String, dynamic> j) =>
      Demand(part: j['part'] as int, name: j['name'] as String, searches: j['searches'] as int);
  final int part;
  final String name;
  final int searches;
}
