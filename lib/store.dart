import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud.dart';
import 'config.dart';
import 'notifications.dart';
import 'models.dart';

class StoreScope extends InheritedNotifier<StoreController> {
  const StoreScope(
      {super.key, required StoreController store, required super.child})
      : super(notifier: store);
  static StoreController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static StoreController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

const Set<String> _legacyDemoProductNames = {
  'Classic Cotton T-Shirt', 'Minimal Everyday Hoodie', 'Urban Crossbody Bag',
  'Classic Analog Watch', 'Slim Everyday Wallet', 'Ceramic Table Vase',
  'Soft Glow Desk Lamp', 'Minimal Cushion Set', 'Daily Care Essentials',
  'Travel Grooming Kit', 'Insulated Steel Bottle', 'Everyday Canvas Tote',
  'Wireless Earbuds', 'Power Bank 10000 mAh', 'Gentle Face Wash',
  'Kids Graphic Tee', 'Everyday Sneakers',
};

/// Order status flow (vertical timeline order)
const List<String> kOrderFlow = [
  'Placed',
  'Confirmed',
  'Packed',
  'Shipped',
  'Out for delivery',
  'Delivered',
];

/// One row of the vertical order-status timeline
class TimelineStep {
  final String title;
  final String subtitle;
  final String date; // formatted, '' if not reached yet
  final String state; // done | current | pending | cancelled
  const TimelineStep(this.title, this.subtitle, this.date, this.state);
}

/// Price breakup of an order (Subtotal, coupon, delivery, platform fee, GST, total)
class OrderBreakdown {
  final int subtotal, coupon, shipping, platformFee, gstPct, gst, total;
  const OrderBreakdown(this.subtotal, this.coupon, this.shipping,
      this.platformFee, this.gstPct, this.gst, this.total);
}

class StoreController extends ChangeNotifier {
  late SharedPreferences prefs;

  List<Product> products = [];
  List<CategoryItem> categories = [];
  List<BannerItem> banners = [];
  List<Coupon> coupons = [];
  List<Review> reviews = [];
  List<AdminUser> admins = [];
  List<String> members = [];
  List<Map<String, dynamic>> orders = []; // my orders
  List<Map<String, dynamic>> cloudOrders = []; // all orders (admin only)
  List<CartLine> cart = [];
  CartLine?
      buyNowLine; // "Buy now" = sirf ek product ka order, cart ko touch nahi karta
  Set<int> favourites = {};
  StoreSettings settings = StoreSettings();

  String customerName = '',
      customerEmail = '',
      phone = '',
      address = '',
      pincode = '',
      city = '';
  String? appliedCoupon;
  String membershipUntil = '';
  int supportTries = 0;
  bool adminUnlocked = false;
  bool dark = false;
  String noticesSeen = '';
  bool _pinTried = false;

  // Fees (Rs / %) - change via setFees()
  int platformFee = 5;
  int gstPercent = 18;

  // login (Supabase)
  String authUserId = '', authEmail = '', _refresh = '';
  String? _serverAdminRole;
  Map<String, dynamic> adminPermissions = {};
  DateTime _tokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _catalogTimer;

  String selectedBrand = 'All';
  String sort = 'Featured';

  // ------------------------------------------------------------ LOAD / SAVE
  List<T> _readList<T>(
      String key, T Function(Map<String, dynamic>) f, List<T> Function() seed) {
    final raw = prefs.getString(key);
    if (raw == null) return seed();
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return seed();
    }
  }

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    products = _readList('z2_products', Product.fromJson, () => <Product>[]);
    categories = _readList(
        'z2_categories', CategoryItem.fromJson, () => <CategoryItem>[]);
    banners =
        _readList('z2_banners', BannerItem.fromJson, () => <BannerItem>[]);
    coupons = _readList('z2_coupons', Coupon.fromJson, () => <Coupon>[]);
    reviews = _readList('z2_reviews', Review.fromJson, () => <Review>[]);
    admins = _readList('z2_admins', AdminUser.fromJson, () => <AdminUser>[])
      ..removeWhere((a) => a.role == 'owner');
    cart = _readList('z2_cart', CartLine.fromJson, () => <CartLine>[]);
    orders = _readList<Map<String, dynamic>>(
        'z_orders', (m) => m, () => <Map<String, dynamic>>[]);
    try {
      members = List<String>.from(
          jsonDecode(prefs.getString('z2_members') ?? '[]') as List);
      favourites = (jsonDecode(prefs.getString('z_favourites') ?? '[]') as List)
          .map((e) => (e as num).toInt())
          .toSet();
      final s = prefs.getString('z2_settings');
      if (s != null) {
        settings = StoreSettings.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map));
      }
    } catch (_) {}
    customerName = prefs.getString('z_name') ?? '';
    customerEmail = prefs.getString('z_email') ?? '';
    phone = prefs.getString('z_phone') ?? '';
    address = prefs.getString('z_address') ?? '';
    pincode = prefs.getString('z_pin') ?? '';
    city = prefs.getString('z_city') ?? '';
    membershipUntil = prefs.getString('z3_member_until') ?? '';
    supportTries = prefs.getInt('z2_support') ?? 0;
    appliedCoupon = prefs.getString('z2_coupon');
    dark = prefs.getBool('z3_dark') ?? false;
    noticesSeen = prefs.getString('z3_notice_seen') ?? '';
    authUserId = prefs.getString('z3_uid') ?? '';
    authEmail = prefs.getString('z3_auth_email') ?? '';
    _refresh = prefs.getString('z3_refresh') ?? '';
    platformFee = prefs.getInt('z4_platform_fee') ?? 5;
    gstPercent = prefs.getInt('z4_gst_pct') ?? 18;
    // No demo products, coupons, banners or local owner credentials are seeded.
    // Existing customer-created local data is preserved.
    products.removeWhere((p) =>
        _legacyDemoProductNames.contains(p.name) && p.sku == 'ZN-${p.id}');
    coupons.removeWhere((c) =>
        (c.code.toUpperCase() == 'WELCOME10' && c.title == 'Welcome offer') ||
        (c.code.toUpperCase() == 'FLAT100' && c.title == 'Flat Rs 100 off'));
  }

  Future<void> _save() async {
    String enc(List l) => jsonEncode(l);
    await prefs.setString(
        'z2_products', enc(products.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_categories', enc(categories.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_banners', enc(banners.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_coupons', enc(coupons.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_reviews', enc(reviews.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'z2_admins', enc(admins.map((e) => e.toJson()).toList()));
    await prefs.setString('z2_cart', enc(cart.map((e) => e.toJson()).toList()));
    await prefs.setString('z_orders', enc(orders));
    await prefs.setString('z2_members', enc(members));
    await prefs.setString('z_favourites', enc(favourites.toList()));
    await prefs.setString('z2_settings', jsonEncode(settings.toJson()));
    await prefs.setString('z_name', customerName);
    await prefs.setString('z_email', customerEmail);
    await prefs.setString('z_phone', phone);
    await prefs.setString('z_address', address);
    await prefs.setString('z_pin', pincode);
    await prefs.setString('z_city', city);
    await prefs.setString('z3_member_until', membershipUntil);
    await prefs.setInt('z2_support', supportTries);
    await prefs.setBool('z3_dark', dark);
    await prefs.setString('z3_notice_seen', noticesSeen);
    await prefs.setString('z3_uid', authUserId);
    await prefs.setString('z3_auth_email', authEmail);
    await prefs.setString('z3_refresh', _refresh);
    await prefs.setInt('z4_platform_fee', platformFee);
    await prefs.setInt('z4_gst_pct', gstPercent);
    if (appliedCoupon == null) {
      await prefs.remove('z2_coupon');
    } else {
      await prefs.setString('z2_coupon', appliedCoupon!);
    }
  }

  /// Call after changing anything.
  Future<void> commit() async {
    notifyListeners();
    await _save();
    if (isAdmin && adminUnlocked && AppConfig.supabaseReady && isLoggedIn) {
      _scheduleCatalogPush();
    }
  }

  // ------------------------------------------------------------ THEME
  Future<void> setDark(bool v) async {
    dark = v;
    await commit();
  }

  // ------------------------------------------------------------ FEES
  Future<void> setFees({int? platform, int? gstPct}) async {
    if (platform != null && platform >= 0) platformFee = platform;
    if (gstPct != null && gstPct >= 0 && gstPct <= 100) gstPercent = gstPct;
    await commit();
  }

  // ------------------------------------------------------------ LOGIN
  bool get isLoggedIn => authUserId.isNotEmpty;

  /// Categories to display: admin-defined ones, plus any category used by an
  /// active product that is not defined yet (so the row is never empty).
  List<CategoryItem> get shownCategories {
    final out = <CategoryItem>[...categories];
    final have = out.map((c) => c.name.toLowerCase()).toSet();
    for (final p in products) {
      final n = p.category.trim();
      if (p.active && n.isNotEmpty && have.add(n.toLowerCase())) {
        out.add(CategoryItem(name: n, icon: 'bag'));
      }
    }
    return out;
  }

  /// Supabase set hai aur user login nahi => login zaroori
  bool get needsLogin => AppConfig.supabaseReady && !isLoggedIn;

  void _setSession(AuthSession s) {
    authUserId = s.userId;
    authEmail = s.email;
    if (s.refreshToken.isNotEmpty) _refresh = s.refreshToken;
    Cloud.setToken(s.accessToken);
    _tokenTime = DateTime.now();
  }

  Future<void> _fresh() async {
    if (!AppConfig.supabaseReady || _refresh.isEmpty) return;
    if (DateTime.now().difference(_tokenTime).inMinutes < 50) return;
    final s = await Cloud.refresh(_refresh);
    if (s != null) _setSession(s);
  }

  Future<String?> login(String email, String password) async {
    final r = await Cloud.signIn(email.trim(), password);
    if (!r.ok) return r.error;
    if (r.data == null) return 'Login failed. Please try again.';
    await _afterLogin(r.data!, '');
    return null;
  }

  Future<String?> loginWithGoogleIdToken(String idToken) async {
    final r = await Cloud.signInWithGoogleIdToken(idToken);
    if (!r.ok) return r.error;
    if (r.data == null) return 'Google login failed. Please try again.';
    await _afterLogin(r.data!, r.data!.name);
    return null;
  }

  /// null = done, 'CONFIRM' = email confirm karna baaki, warna error text
  Future<String?> signup(String name, String email, String password) async {
    final r = await Cloud.signUp(email.trim(), password, name.trim());
    if (!r.ok) return r.error;
    if (r.data == null) return 'CONFIRM';
    await _afterLogin(r.data!, name.trim());
    return null;
  }

  Future<void> _afterLogin(AuthSession s, String fallbackName) async {
    _setSession(s);
    await _refreshAdminRole();
    final nm = s.name.isNotEmpty ? s.name : fallbackName;
    if (nm.isNotEmpty) customerName = nm;
    customerEmail = s.email;
    orders = [];
    membershipUntil = '';
    await commit();
    await syncCloud();
    final deviceTokenError = await PushNotifications.registerCurrentDevice();
    debugPrint(
        'POST-LOGIN DEVICE TOKEN SAVE: ${deviceTokenError ?? "SUCCESS"}');
  }

  Future<void> logout() async {
    await Cloud.signOut();
    Cloud.setToken(null);
    authUserId = '';
    authEmail = '';
    _refresh = '';
    adminUnlocked = false;
    buyNowLine = null;
    cloudOrders = [];
    orders = [];
    membershipUntil = '';
    customerName = '';
    customerEmail = '';
    phone = '';
    address = '';
    await commit();
  }

  // ------------------------------------------------------------ CLOUD SYNC
  Future<void> bootCloud() async {
    if (!AppConfig.supabaseReady) return;
    await syncCloud();
  }

  Map<String, dynamic> _orderFromRow(Map<String, dynamic> r) {
    final d = Map<String, dynamic>.from((r['data'] as Map?) ?? const {});
    d['status'] = '${r['status'] ?? d['status'] ?? 'Placed'}';
    d['id'] = '${r['id']}';
    return d;
  }

  Future<String?> _pushOrder(Map<String, dynamic> o) => Cloud.insert('orders', {
        'id': o['id'],
        'user_id': authUserId,
        'user_email': authEmail,
        'status': o['status'],
        'data': o,
      });

  Future<void> syncCloud() async {
    if (!AppConfig.supabaseReady) return;
    await _fresh();
    if (isLoggedIn) await _refreshAdminRole();

    // store catalog (products, banners, coupons, settings) - admin ne jo set kiya
    final cat = await Cloud.select('app_data',
        query: {'key': 'eq.catalog', 'select': 'data'});
    if (cat != null) {
      if (cat.isNotEmpty) {
        final cleanedDemoCatalog =
            _applyCatalog(Map<String, dynamic>.from(cat.first['data'] as Map));
        if (cleanedDemoCatalog && isAdmin) await _pushCatalog();
      } else if (isAdmin && isLoggedIn) {
        await _pushCatalog();
      }
    }

    // reviews (sabko dikhte hain)
    final rv = await Cloud.select('reviews', query: {
      'select': 'product_id,user_id,name,rating,body,created_at',
      'order': 'created_at.asc'
    });
    if (rv != null) {
      reviews = rv
          .map((r) => Review(
                productId: ((r['product_id'] ?? 0) as num).toInt(),
                rating: ((r['rating'] ?? 5) as num).toInt(),
                name: '${r['name'] ?? 'Customer'}',
                text: '${r['body'] ?? ''}',
                date: '${r['created_at'] ?? ''}',
                uid: '${r['user_id'] ?? ''}',
              ))
          .toList();
    }

    if (isLoggedIn) {
      final mine = await Cloud.select('orders', query: {
        'select': 'id,status,data,created_at',
        'user_id': 'eq.$authUserId',
        'order': 'created_at.desc'
      });
      if (mine != null) {
        final fetched = mine.map(_orderFromRow).toList();
        final stillPending = orders
            .where((o) =>
                o['pending'] == true && !fetched.any((f) => f['id'] == o['id']))
            .toList();
        orders = [...stillPending, ...fetched];
      }
      final m = await Cloud.select('memberships', query: {
        'select': 'user_id,active_until',
        'user_id': 'eq.$authUserId'
      });
      if (m != null) {
        membershipUntil = m.isEmpty ? '' : '${m.first['active_until']}';
      }

      if (isAdmin) {
        final all = await Cloud.select('orders', query: {
          'select': 'id,status,data,created_at',
          'order': 'created_at.desc',
          'limit': '500'
        });
        if (all != null) cloudOrders = all.map(_orderFromRow).toList();
        final mm = await Cloud.select('memberships',
            query: {'select': 'user_id,active_until'});
        if (mm != null) {
          members = mm
              .where((e) =>
                  (DateTime.tryParse('${e['active_until']}') ?? DateTime(2000))
                      .isAfter(DateTime.now()))
              .map((e) => '${e['user_id']}')
              .toList();
        }
      }
    }
    notifyListeners();
    await _save();
  }

  Map<String, dynamic> _catalogJson() => {
        'products': products.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'banners': banners.map((e) => e.toJson()).toList(),
        'coupons': coupons.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  bool _applyCatalog(Map<String, dynamic> j) {
    try {
      List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
          ((j[k] as List?) ?? const [])
              .map((e) => f(Map<String, dynamic>.from(e as Map)))
              .toList();
      final rawProducts = list('products', Product.fromJson);
      final p = rawProducts
        ..removeWhere((x) =>
            _legacyDemoProductNames.contains(x.name) && x.sku == 'ZN-${x.id}');
      final c = list('categories', CategoryItem.fromJson);
      final rawBanners = list('banners', BannerItem.fromJson);
      final b = rawBanners
        ..removeWhere((x) =>
            x.image.trim().isEmpty &&
            ['Fashion', 'Accessories', 'Home'].contains(x.category));
      final rawCoupons = list('coupons', Coupon.fromJson);
      final cp = rawCoupons
        ..removeWhere((x) =>
            (x.code.toUpperCase() == 'WELCOME10' &&
                x.title == 'Welcome offer') ||
            (x.code.toUpperCase() == 'FLAT100' &&
                x.title == 'Flat Rs 100 off'));
      final st = StoreSettings.fromJson(
          Map<String, dynamic>.from((j['settings'] as Map?) ?? const {}));
      products = p;
      categories = c;
      banners = b;
      coupons = cp;
      settings = st;
      return p.length != rawProducts.length ||
          b.length != rawBanners.length ||
          cp.length != rawCoupons.length;
    } catch (_) {
      return false;
    }
  }

  Future<void> _pushCatalog() async {
    await _fresh();
    await Cloud.insert(
        'app_data',
        {
          'key': 'catalog',
          'data': _catalogJson(),
          'updated_at': DateTime.now().toUtc().toIso8601String()
        },
        upsert: true);
  }

  void _scheduleCatalogPush() {
    _catalogTimer?.cancel();
    _catalogTimer = Timer(const Duration(seconds: 2), _pushCatalog);
  }

  // ------------------------------------------------------------ SETTINGS / ROLE
  Color get accent => settings.accentColor;

  Future<void> _refreshAdminRole() async {
    if (!isLoggedIn || !AppConfig.supabaseReady) {
      _serverAdminRole = null;
      adminPermissions = {};
      return;
    }
    final rows = await Cloud.select('admin_roles', query: {
      'select': 'role,active,permissions',
      'user_id': 'eq.$authUserId',
      'limit': '1',
    });
    if (rows != null && rows.isNotEmpty && rows.first['active'] == true) {
      _serverAdminRole = '${rows.first['role'] ?? ''}';
      adminPermissions = Map<String, dynamic>.from(
          (rows.first['permissions'] as Map?) ?? const {});
    } else {
      _serverAdminRole = null;
      adminPermissions = {};
    }
  }

  AdminUser? get currentAdmin {
    if (_serverAdminRole != null && _serverAdminRole!.isNotEmpty) {
      return AdminUser(
        name: customerName.isEmpty ? 'Team Admin' : customerName,
        phone: phone,
        pin: '',
        role: _serverAdminRole!,
      );
    }
    // Bootstrap compatibility for the existing owner email allow-list.
    if (AppConfig.isAdminEmail(authEmail)) {
      return AdminUser(
          name: customerName.isEmpty ? 'Super Admin' : customerName,
          phone: phone,
          pin: '',
          role: 'super_admin');
    }
    return null;
  }

  bool get isAdmin => currentAdmin != null;
  bool canManage(String permission) {
    if (isOwner) return true;
    if (_serverAdminRole == 'staff') {
      return permission == 'products.manage' || permission == 'orders.manage';
    }
    return adminPermissions[permission] == true ||
        adminPermissions['*'] == true;
  }

  bool get isOwner =>
      currentAdmin?.role == 'owner' || currentAdmin?.role == 'super_admin';

  bool unlockAdmin(String pin) {
    // Admin access is tied to the authenticated account; never rely on a hard-coded app PIN.
    if (isAdmin && isLoggedIn) {
      adminUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockAdmin() {
    adminUnlocked = false;
    notifyListeners();
  }

  // ------------------------------------------------------------ CATALOG
  Product? productById(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  int get nextProductId => products.isEmpty
      ? 101
      : products.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

  List<String> get brands {
    final out = <String>[];
    for (final p in products) {
      if (p.active && p.brand.isNotEmpty && !out.contains(p.brand)) {
        out.add(p.brand);
      }
    }
    return out;
  }

  String iconKeyFor(String category) {
    for (final c in categories) {
      if (c.name == category) return c.icon;
    }
    return 'bag';
  }

  List<Product> listProducts(
      {String category = 'All',
      String brand = 'All',
      String q = '',
      String? sortBy}) {
    final qq = q.toLowerCase().trim();
    final list = products
        .where((p) =>
            p.active &&
            (category == 'All' || p.category == category) &&
            (brand == 'All' || p.brand == brand) &&
            (qq.isEmpty ||
                '${p.name} ${p.brand} ${p.category}'
                    .toLowerCase()
                    .contains(qq)))
        .toList();
    final so = sortBy ?? sort;
    if (so == 'Price: Low to High') {
      list.sort((a, b) => a.price.compareTo(b.price));
    }
    if (so == 'Price: High to Low') {
      list.sort((a, b) => b.price.compareTo(a.price));
    }
    if (so == 'Top Rated') {
      list.sort((a, b) => ratingOf(b.id).compareTo(ratingOf(a.id)));
    }
    return list;
  }

  void setBrand(String b) {
    selectedBrand = b;
    notifyListeners();
  }

  void setSort(String s) {
    sort = s;
    notifyListeners();
  }

  // ------------------------------------------------------------ REVIEWS
  List<Review> reviewsOf(int pid) =>
      reviews.where((r) => r.productId == pid).toList().reversed.toList();

  double ratingOf(int pid) {
    final l = reviews.where((r) => r.productId == pid).toList();
    if (l.isEmpty) return 0;
    return l.fold<int>(0, (a, r) => a + r.rating) / l.length;
  }

  String get _myUid => authUserId.isEmpty ? 'local' : authUserId;

  /// Kya is user ne ye product order kiya hai (cancelled chhodke)?
  bool hasPurchased(int pid) {
    for (final o in orders) {
      if (o['status'] == 'Cancelled') continue;
      for (final raw in ((o['items'] as List?) ?? const [])) {
        final it = raw as Map;
        if (((it['pid'] ?? it['id'] ?? 0) as num).toInt() == pid) return true;
      }
    }
    return false;
  }

  bool hasReviewed(int pid) =>
      reviews.any((r) => r.productId == pid && r.uid == _myUid);

  bool canReview(int pid) => hasPurchased(pid) && !hasReviewed(pid);

  /// null = ok, warna error message
  Future<String?> addReview(int pid, int rating, String text) async {
    if (!hasPurchased(pid)) {
      return 'Only customers who ordered this product can review it.';
    }
    if (hasReviewed(pid)) return 'You have already reviewed this product.';
    final nm = customerName.isEmpty ? 'Customer' : customerName;
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final err = await Cloud.insert('reviews', {
        'product_id': pid,
        'user_id': authUserId,
        'name': nm,
        'rating': rating,
        'body': text
      });
      if (err != null) return err;
    }
    reviews.add(Review(
        productId: pid,
        rating: rating,
        name: nm,
        text: text,
        date: DateTime.now().toIso8601String(),
        uid: _myUid));
    await commit();
    return null;
  }

  // ------------------------------------------------------------ FAVOURITES
  Future<void> toggleFavourite(int id) async {
    favourites.contains(id) ? favourites.remove(id) : favourites.add(id);
    await commit();
  }

  // ------------------------------------------------------------ MEMBERSHIP
  DateTime? get membershipEnds => DateTime.tryParse(membershipUntil)?.toLocal();
  bool get isMember => membershipEnds?.isAfter(DateTime.now()) ?? false;
  int get memberDaysLeft =>
      isMember ? membershipEnds!.difference(DateTime.now()).inDays + 1 : 0;

  // ------------------------------------------------------------ CART + PRICING
  List<CartLine> get cartLines =>
      cart.where((l) => productById(l.pid) != null).toList();

  /// Buy now chal raha ho to sirf wahi ek product, warna poora cart
  List<CartLine> get activeLines {
    final b = buyNowLine;
    if (b != null && productById(b.pid) != null) return [b];
    return cartLines;
  }

  int get itemCount => cartLines.fold(0, (a, l) => a + l.qty);
  int get subtotal =>
      activeLines.fold(0, (a, l) => a + productById(l.pid)!.price * l.qty);

  // Membership ab discount nahi, free + fast delivery deti hai
  int get memberPct => 0;
  int get potentialPct => 0;
  int get memberDiscount => 0;

  Coupon? get coupon {
    if (appliedCoupon == null) return null;
    for (final c in coupons) {
      if (c.code.toLowerCase() == appliedCoupon!.toLowerCase()) return c;
    }
    return null;
  }

  int get couponDiscount => coupon?.discountFor(subtotal) ?? 0;

  /// Delivery fee jo non-member ko lagti
  int get normalShipping => subtotal == 0 || subtotal >= settings.freeShipAbove
      ? 0
      : settings.shippingFee;
  int get shipping => isMember ? 0 : normalShipping;

  /// Platform fee (empty cart par 0)
  int get platformFeeAmount => subtotal == 0 ? 0 : platformFee;

  /// GST on (subtotal - coupon)
  int get gstAmount {
    final base = subtotal - couponDiscount;
    if (base <= 0) return 0;
    return (base * gstPercent / 100).round();
  }

  int get total =>
      subtotal - couponDiscount + shipping + platformFeeAmount + gstAmount;
  int get etaDays => isMember ? settings.etaDaysMember : settings.etaDays;

  Future<void> addToCart(int pid, {String size = '', String color = ''}) async {
    final k = CartLine(pid: pid, size: size, color: color).key;
    final i = cart.indexWhere((l) => l.key == k);
    if (i >= 0) {
      cart[i].qty += 1;
    } else {
      cart.add(CartLine(pid: pid, size: size, color: color));
    }
    await commit();
  }

  void startBuyNow(int pid, {String size = '', String color = ''}) {
    buyNowLine = CartLine(pid: pid, size: size, color: color);
    notifyListeners();
  }

  void endBuyNow() {
    buyNowLine = null; // notify nahi (dispose ke time safe)
  }

  Future<void> setQty(CartLine l, int q) async {
    if (q <= 0) {
      cart.removeWhere((x) => x.key == l.key);
    } else {
      l.qty = q;
    }
    await commit();
  }

  Future<String?> applyCoupon(String code) async {
    final c = code.trim().toLowerCase();
    for (final x in coupons) {
      if (x.code.toLowerCase() == c && x.active) {
        if (subtotal < x.minOrder) {
          return 'Add items worth ₹${x.minOrder - subtotal} more to use this coupon';
        }
        appliedCoupon = x.code;
        await commit();
        return null;
      }
    }
    return 'Invalid or expired coupon';
  }

  Future<void> removeCoupon() async {
    appliedCoupon = null;
    await commit();
  }

  // ------------------------------------------------------------ PROFILE
  Future<void> saveProfile(
      {String? name,
      String? email,
      String? mobile,
      String? addr,
      String? pin,
      String? town}) async {
    if (name != null) customerName = name;
    if (email != null) customerEmail = email;
    if (mobile != null) phone = mobile;
    if (addr != null) address = addr;
    if (pin != null) pincode = pin;
    if (town != null) city = town;
    if (!isAdmin) adminUnlocked = false;
    await commit();
  }

  // ------------------------------------------------------------ PIN CODE
  Future<String?> lookupPin(String pin) async {
    try {
      final r = await http
          .get(Uri.parse('https://api.postalpincode.in/pincode/$pin'))
          .timeout(const Duration(seconds: 7));
      final j = jsonDecode(r.body) as List;
      final first = j.first as Map;
      if (first['Status'] == 'Success') {
        final po = (first['PostOffice'] as List).first as Map;
        return '${po['District']}';
      }
    } catch (_) {}
    return null;
  }

  Future<void> setPin(String pin) async {
    final town = await lookupPin(pin);
    pincode = pin;
    if (town != null) city = town;
    await commit();
  }

  /// Approximate auto-detect using the network location (no permission needed)
  Future<bool> autoDetectPin() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 7));
      if (r.statusCode != 200) return false;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final p = '${j['postal'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
      if (p.length == 6) {
        pincode = p;
        city = '${j['city'] ?? city}';
        await commit();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> autoPinOnce() async {
    if (pincode.isNotEmpty || _pinTried) return;
    _pinTried = true;
    await autoDetectPin();
  }

  // ------------------------------------------------------------ ORDERS
  Map<String, dynamic>? orderById(String id) {
    for (final o in orders) {
      if (o['id'] == id) return o;
    }
    for (final o in cloudOrders) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  /// Admin ko saare customers ke orders (cloud se), warna apne orders
  List<Map<String, dynamic>> get adminOrders =>
      cloudOrders.isNotEmpty ? cloudOrders : orders;

  /// Payment se pehle stock check
  String? stockIssue() {
    for (final l in activeLines) {
      final p = productById(l.pid)!;
      if (p.stock < l.qty) return '${p.name}: only ${p.stock} left in stock';
    }
    return null;
  }

  Future<String?> placeOrder(String payment, {String paymentId = ''}) async {
    if (AppConfig.supabaseReady) {
      return 'Use the secure server checkout flow. Direct client-side order creation is disabled.';
    }
    final lines = activeLines;
    if (lines.isEmpty) return 'Your cart is empty';
    final issue = stockIssue();
    if (issue != null) return issue;
    final single = buyNowLine != null;
    final now = DateTime.now();
    final items = lines.map((l) {
      final p = productById(l.pid)!;
      p.stock -= l.qty;
      return {
        'pid': p.id,
        'name': p.name,
        'brand': p.brand,
        'size': l.size,
        'color': l.color,
        'qty': l.qty,
        'price': p.price
      };
    }).toList();
    final order = <String, dynamic>{
      'id': 'ZV${now.millisecondsSinceEpoch.toString().substring(6)}',
      'date': now.toIso8601String(),
      'items': items,
      'subtotal': subtotal,
      'memberDiscount': 0,
      'couponDiscount': couponDiscount,
      'coupon': appliedCoupon ?? '',
      'shipping': shipping,
      'platformFee': platformFeeAmount,
      'gstPct': gstPercent,
      'gst': gstAmount,
      'total': total,
      'payment': payment,
      'paymentId': paymentId,
      'status': 'Placed',
      'history': [
        {'status': 'Placed', 'date': now.toIso8601String()}
      ],
      'name': customerName,
      'phone': phone,
      'email': customerEmail,
      'address': '$address, $city - $pincode',
      'member': isMember,
    };
    orders.insert(0, order);
    if (single) {
      buyNowLine = null;
    } else {
      cart.clear();
    }
    appliedCoupon = null;
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final err = await _pushOrder(order);
      if (err != null) order['pending'] = true; // net aate hi dobara push hoga
    }
    await commit();
    return 'OK:${order['id']}';
  }

  Future<void> setOrderStatus(String id, String status) async {
    final o = orderById(id);
    if (o == null || o['status'] == status) return;
    final wasCancelled = o['status'] == 'Cancelled';
    final h = List<dynamic>.from((o['history'] as List?) ?? const []);
    h.add({'status': status, 'date': DateTime.now().toIso8601String()});
    for (final list in [orders, cloudOrders]) {
      for (final x in list) {
        if (x['id'] == id) {
          x['status'] = status;
          x['history'] = h;
        }
      }
    }
    // stock handling
    if (status == 'Cancelled' && !wasCancelled) {
      for (final raw in (o['items'] as List)) {
        final it = raw as Map;
        final pid = ((it['pid'] ?? it['id'] ?? 0) as num).toInt();
        final p = productById(pid);
        if (p != null) p.stock += ((it['qty'] ?? 0) as num).toInt();
      }
    }
    if (AppConfig.supabaseReady && isLoggedIn) {
      await _fresh();
      final data = Map<String, dynamic>.from(o)..remove('pending');
      await Cloud.update(
          'orders', {'id': 'eq.$id'}, {'status': status, 'data': data});
    }
    await commit();
  }

  // ------------------------------------------------------------ ORDER DETAILS (breakup + delivery rows)
  int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  /// Price breakup of a saved order. Old orders (without the new fields)
  /// still work: missing fees show as 0 and GST is derived from total.
  OrderBreakdown breakdownOf(Map<String, dynamic> o) {
    final sub = _n(o['subtotal']);
    final cpn = _n(o['couponDiscount']);
    final ship = _n(o['shipping']);
    final fee = _n(o['platformFee']);
    final tot = _n(o['total']);
    final pct = o['gstPct'] == null ? 0 : _n(o['gstPct']);
    final gst = o['gst'] != null
        ? _n(o['gst'])
        : (tot - (sub - cpn + ship + fee)).clamp(0, 1 << 31).toInt();
    return OrderBreakdown(sub, cpn, ship, fee, pct, gst, tot);
  }

  /// "9:30am, 16 Jan 2026"
  String formatStamp(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour >= 12 ? 'pm' : 'am';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h12:$mm$ap, ${d.day} ${m[d.month - 1]} ${d.year}';
  }

  /// "Samsung TV x1, Shoes x2"
  String itemsSummary(Map<String, dynamic> o) {
    final l = ((o['items'] as List?) ?? const []).map((raw) {
      final it = raw as Map;
      return '${it['name']} x${it['qty']}';
    }).toList();
    return l.isEmpty ? '-' : l.join(', ');
  }

  /// Vertical timeline steps for an order (with real time from history)
  List<TimelineStep> timelineFor(Map<String, dynamic> o) {
    final status = '${o['status'] ?? 'Placed'}';
    final hist = ((o['history'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    String dateOf(String st) {
      for (final h in hist.reversed) {
        if ('${h['status']}' == st) return formatStamp(h['date']);
      }
      return '';
    }

    final out = <TimelineStep>[];
    if (status == 'Cancelled') {
      for (final st in kOrderFlow) {
        final d = dateOf(st);
        if (d.isNotEmpty) out.add(TimelineStep(st, _statusText[st] ?? st, d, 'done'));
      }
      if (out.isEmpty) {
        out.add(TimelineStep('Placed', _statusText['Placed']!,
            formatStamp(o['date']), 'done'));
      }
      out.add(TimelineStep('Cancelled', _statusText['Cancelled']!,
          dateOf('Cancelled'), 'cancelled'));
      return out;
    }

    var idx = kOrderFlow.indexOf(status);
    if (idx < 0) idx = 0;
    for (var i = 0; i < kOrderFlow.length; i++) {
      final st = kOrderFlow[i];
      var d = dateOf(st);
      if (i == 0 && d.isEmpty) d = formatStamp(o['date']);
      String state;
      if (i < idx || (i == idx && st == 'Delivered')) {
        state = 'done';
      } else if (i == idx) {
        state = 'current';
      } else {
        state = 'pending';
      }
      out.add(TimelineStep(
          st, _statusText[st] ?? st, state == 'pending' ? '' : d, state));
    }
    return out;
  }

  // ------------------------------------------------------------ SUPPORT
  Future<void> trackSupport() async {
    supportTries += 1;
    await commit();
  }

  // ------------------------------------------------------------ NOTIFICATIONS
  static const Map<String, String> _statusText = {
    'Placed': 'Your order has been placed.',
    'Confirmed': 'Your order is confirmed.',
    'Packed': 'Your order is packed and ready to ship.',
    'Shipped': 'Your order has been shipped.',
    'Out for delivery': 'Your order is out for delivery today.',
    'Delivered': 'Your order was delivered. Share a review!',
    'Cancelled': 'Your order was cancelled.',
  };

  List<AppNotice> get notices {
    final out = <AppNotice>[];
    for (final o in orders) {
      for (final raw in ((o['history'] as List?) ?? const [])) {
        final h = raw as Map;
        final st = '${h['status']}';
        out.add(AppNotice(
            kind: 'order',
            title: 'Order #${o['id']} · $st',
            body: _statusText[st] ?? st,
            date: '${h['date']}'));
      }
    }
    if (isAdmin) {
      for (final o
          in adminOrders.where((o) => o['status'] == 'Placed').take(20)) {
        out.add(AppNotice(
            kind: 'admin',
            title: 'New order #${o['id']}',
            body: '${o['name'] ?? 'Customer'} · ₹${o['total']}',
            date: '${o['date']}'));
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    for (final c in coupons.where((c) => c.active && c.notify)) {
      out.add(AppNotice(
          kind: 'offer',
          title: '${c.label} · ${c.code}',
          body: c.title.isEmpty ? 'Special offer' : c.title));
    }
    return out;
  }

  int get unreadNotices {
    final n = notices;
    var c = n
        .where((x) => x.date.isNotEmpty && x.date.compareTo(noticesSeen) > 0)
        .length;
    if (noticesSeen.isEmpty) c += n.where((x) => x.kind == 'offer').length;
    return c;
  }

  Future<void> markNoticesSeen() async {
    noticesSeen = DateTime.now().toIso8601String();
    await commit();
  }

  // ------------------------------------------------------------ DASHBOARD
  int get ordersCount => adminOrders.length;
  int get cancelledCount =>
      adminOrders.where((o) => o['status'] == 'Cancelled').length;
  int get revenue => adminOrders
      .where((o) => o['status'] != 'Cancelled')
      .fold(0, (a, o) => a + ((o['total'] ?? 0) as num).toInt());
  int get stockUnits => products.fold(0, (a, p) => a + p.stock);
  List<Product> get lowStock =>
      products.where((p) => p.stock > 0 && p.stock <= 5).toList();
  List<Product> get outOfStock => products.where((p) => p.stock <= 0).toList();
  List<Coupon> get notifications =>
      coupons.where((c) => c.active && c.notify).toList();
}

// ==================================================================
// UI WIDGETS (order details screen me direct use karo)
//   DeliveryDetailsCard(order: o)   -> Delivery + price breakup card
//   OrderStatusTimeline(order: o)   -> Vertical professional timeline
// ==================================================================

class DeliveryDetailsCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const DeliveryDetailsCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = s.breakdownOf(order);
    final outer = isDark ? const Color(0xFF1E2430) : const Color(0xFFEEF2FB);
    final inner = isDark ? const Color(0xFF12151C) : Colors.white;
    final muted = cs.onSurface.withOpacity(0.6);

    Widget row(String k, String v,
        {Color? vColor, bool bold = false, IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: vColor),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(v,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                            color: vColor ?? cs.onSurface)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final divider = Divider(height: 14, color: cs.onSurface.withOpacity(0.08));
    final payment = '${order['payment'] ?? ''}';
    final memberFree = order['member'] == true && b.shipping == 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: outer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(children: [
              Icon(Icons.local_shipping_rounded, size: 20, color: muted),
              const SizedBox(width: 8),
              Text('Delivery Details',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: inner, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              row('Receiver', '${order['name'] ?? '-'}', bold: true),
              row('Address', '${order['address'] ?? '-'}', bold: true),
              row('Contact', '${order['phone'] ?? '-'}', bold: true),
              row('Item', s.itemsSummary(order), bold: true),
              if (payment.isNotEmpty) row('Payment', payment, bold: true),
              divider,
              row('Subtotal', '₹${b.subtotal}'),
              if (b.coupon > 0)
                row('Coupon${'${order['coupon'] ?? ''}'.isEmpty ? '' : ' (${order['coupon']})'}',
                    '- ₹${b.coupon}',
                    vColor: Colors.green.shade600),
              row('Delivery charges',
                  b.shipping == 0 ? (memberFree ? 'FREE (Member)' : 'FREE') : '₹${b.shipping}',
                  vColor: b.shipping == 0 ? Colors.green.shade600 : null),
              row('Platform fee', b.platformFee == 0 ? '₹0' : '₹${b.platformFee}'),
              row(b.gstPct > 0 ? 'GST (${b.gstPct}%)' : 'GST', '₹${b.gst}'),
              divider,
              row('Total paid', '₹${b.total}', bold: true),
            ]),
          ),
        ],
      ),
    );
  }
}

class OrderStatusTimeline extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderStatusTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final steps = s.timelineFor(order);
    final ink = cs.onSurface;
    final grey = cs.onSurface.withOpacity(0.18);
    const red = Color(0xFFE53935);

    Widget dot(TimelineStep st) {
      switch (st.state) {
        case 'done':
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 15, color: cs.surface),
          );
        case 'current':
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surface,
                border: Border.all(color: ink, width: 2.5)),
            child: Center(
              child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: ink, shape: BoxShape.circle)),
            ),
          );
        case 'cancelled':
          return Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: red, shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
          );
        default:
          return Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: grey, shape: BoxShape.circle));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Status',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(children: [
                      dot(steps[i]),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              color: steps[i].state == 'done' &&
                                      steps[i + 1].state != 'pending'
                                  ? (steps[i + 1].state == 'cancelled' ? red : ink)
                                  : grey,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: i == steps.length - 1 ? 0 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].title,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: steps[i].state == 'pending'
                                      ? FontWeight.w500
                                      : FontWeight.w800,
                                  color: steps[i].state == 'cancelled'
                                      ? red
                                      : steps[i].state == 'pending'
                                          ? ink.withOpacity(0.4)
                                          : ink)),
                          if (steps[i].state != 'pending') ...[
                            const SizedBox(height: 2),
                            Text(steps[i].subtitle,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.3,
                                    color: ink.withOpacity(0.65))),
                          ],
                          if (steps[i].date.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(steps[i].date,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: ink.withOpacity(0.45))),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
