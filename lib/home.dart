import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

void openCategory(BuildContext context, String name) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: name)));

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final products = s.listProducts(brand: s.selectedBrand);
    final notifCount = s.unreadNotices;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFE5EBDD), Color(0xFFF8F8F5), Color(0xFFE9EDE4)],
        ),
      ),
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GestureDetector(
              onTap: () => showPinSheet(context),
              child: Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE8E8E3), borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.location_on_outlined, size: 19, color: ink)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DELIVER TO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: muted)),
                  const SizedBox(height: 2),
                  Text(s.pincode.isEmpty ? 'Choose your location' : '${s.city.isEmpty ? 'Your location' : s.city} · ${s.pincode}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
                ])),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 21, color: ink),
                const SizedBox(width: 4),
                IconButton(visualDensity: VisualDensity.compact, tooltip: 'Notifications',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  icon: Badge(isLabelVisible: notifCount > 0, label: Text('$notifCount'), child: const Icon(Icons.notifications_none_rounded, color: ink))),
              ]),
            ),
          ),
        ),
        SliverPersistentHeader(pinned: true, delegate: _StickySearchDelegate(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
        )),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BannerSlider())),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Category', action: 'See all')),
        SliverToBoxAdapter(
          child: SizedBox(height: 88,
            child: s.shownCategories.isEmpty
              ? const Center(child: Text('Categories will appear here', style: TextStyle(color: muted, fontSize: 12)))
              : ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: s.shownCategories.length, itemBuilder: (c, i) => _CategoryTile(item: s.shownCategories[i], index: i)),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Featured brands', action: 'Explore')),
        SliverToBoxAdapter(child: SizedBox(height: 106,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14),
            children: s.brands.map((b) => _BrandTile(name: b)).toList()),
        )),
        const SliverToBoxAdapter(child: SectionHeading(title: 'New arrivals', action: 'Fresh picks')),
        if (products.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 30),
            child: EmptyState(title: 'No products found', subtitle: 'Try another brand or category.')))
        else
          SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            sliver: SliverGrid(delegate: SliverChildBuilderDelegate(
              (c, i) => ProductCard(product: products[i], index: i), childCount: products.length),
              gridDelegate: productGridDelegate())),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Trending now')),
        if (products.isNotEmpty)
          SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            sliver: SliverGrid(delegate: SliverChildBuilderDelegate(
              (c, i) => ProductCard(product: products[(i + 1) % products.length], index: i + 1),
              childCount: products.length > 4 ? 4 : products.length), gridDelegate: productGridDelegate())),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Curated for you')),
        if (products.isNotEmpty)
          SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            sliver: SliverGrid(delegate: SliverChildBuilderDelegate(
              (c, i) => ProductCard(product: products[(i + 2) % products.length], index: i + 2),
              childCount: products.length > 4 ? 4 : products.length), gridDelegate: productGridDelegate())),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Popular products')),
        if (products.isNotEmpty)
          SliverPadding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: SliverGrid(delegate: SliverChildBuilderDelegate(
              (c, i) => ProductCard(product: products[(i + products.length ~/ 2) % products.length], index: i + 3),
              childCount: products.length > 4 ? 4 : products.length), gridDelegate: productGridDelegate())),
      ]),
    );
  }
}

class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onTap;
  _StickySearchDelegate({required this.onTap});
  @override double get minExtent => 72;
  @override double get maxExtent => 72;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9EDE4), Color(0xFFF5F6F1)])),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Material(
      color: Colors.white, elevation: overlapsContent ? 4 : 1,
      shadowColor: const Color(0x1A000000), borderRadius: BorderRadius.circular(25),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(25),
        child: Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF1F3ED)]),
            border: Border.all(color: const Color(0xFFDDE1D7)),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 23, color: Color(0xFF30352D)),
            const SizedBox(width: 12),
            const Expanded(child: Text('What are you looking for?', style: TextStyle(color: Color(0xFF8A8E85), fontSize: 13, fontWeight: FontWeight.w500))),
            Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0xFFE9EDE4), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF333A2E))),
          ]),
        ),
      ),
    ),
  );
  @override bool shouldRebuild(covariant _StickySearchDelegate oldDelegate) => false;
}

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});
  @override State<BannerSlider> createState() => _BannerSliderState();
}
class _BannerSliderState extends State<BannerSlider> {
  final PageController controller = PageController();
  Timer? timer;
  int page = 0;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !controller.hasClients) return;
      final n = StoreScope.read(context).banners.length;
      if (n < 2) return;
      controller.animateToPage((page + 1) % n, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }
  @override
  void dispose() { timer?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final list = StoreScope.of(context).banners;
    final ac = accentOf(context);
    Widget blankBanner() => ClipRRect(borderRadius: BorderRadius.circular(22), child: AspectRatio(aspectRatio: 4 / 3,
      child: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFBDCCA7), Color(0xFFE5EBDD), Color(0xFFD5DFCA)]))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.48), borderRadius: BorderRadius.circular(20)),
              child: const Text('ZEN VORA EDIT', style: TextStyle(color: Color(0xFF30392B), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
            const SizedBox(height: 10),
            const Text('Discover Your\nEveryday Style', style: TextStyle(color: Color(0xFF20271D), fontSize: 25, height: 1.08, fontWeight: FontWeight.w900)),
            const SizedBox(height: 13),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: const Color(0xFF20251D), borderRadius: BorderRadius.circular(22)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Shop Now', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)), SizedBox(width: 5), Icon(Icons.arrow_outward_rounded, size: 13, color: Colors.white)])),
          ])),
      ])));
    if (list.isEmpty) return Column(children: [blankBanner(), const SizedBox(height: 8)]);
    return Column(children: [
      AspectRatio(aspectRatio: 4 / 3, child: ClipRRect(borderRadius: BorderRadius.circular(22),
        child: PageView.builder(controller: controller, itemCount: list.length,
          onPageChanged: (v) => setState(() => page = v),
          itemBuilder: (c, i) {
            final b = list[i];
            return GestureDetector(onTap: () { if (b.category.isNotEmpty) openCategory(context, b.category); },
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFBDCCA7), Color(0xFFE5EBDD), Color(0xFFD5DFCA)]))),
                if (b.image.trim().isNotEmpty) NetImage(url: b.image, fit: BoxFit.cover, fallback: const SizedBox.expand()),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [const Color(0xAA172018), const Color(0x44172018), Colors.transparent]))),
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 110, 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(.45))),
                      child: const Text('LIMITED OFFER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1))),
                    const SizedBox(height: 9),
                    const Text('Find Your\nNew Favourite', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.08, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Shop Now', style: TextStyle(color: Color(0xFF20251D), fontSize: 11, fontWeight: FontWeight.w800)), SizedBox(width: 5), Icon(Icons.arrow_outward_rounded, size: 13, color: Color(0xFF20251D))])),
                  ])),
              ]));
          })),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(list.length, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 180), margin: const EdgeInsets.symmetric(horizontal: 3), width: i == page ? 22 : 6, height: 6,
        decoration: BoxDecoration(color: i == page ? ac : const Color(0xFFD1D5CB), borderRadius: BorderRadius.circular(9))))),
    ]);
  }
}
class _CategoryTile extends StatelessWidget {
  final CategoryItem item;
  final int index;
  const _CategoryTile({required this.item, required this.index});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () => openCategory(context, item.name),
    child: SizedBox(width: 76, child: Column(children: [
      Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFF4F5F0), shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE1E4DC)), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 9, offset: Offset(0, 3))]),
        child: Icon(iconFor(item.icon), size: 23, color: const Color(0xFF30352D))),
      const SizedBox(height: 6),
      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
    ])));
}

class _BrandTile extends StatelessWidget {
  final String name;
  const _BrandTile({required this.name});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final active = s.selectedBrand == name;
    final ac = accentOf(context);
    return GestureDetector(
      onTap: () => s.setBrand(active ? 'All' : name),
      child: Container(
        width: 132,
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: active ? ac : const Color(0xFFE6E8E1), width: active ? 1.5 : 1),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 9, offset: Offset(0, 3))],
        ),
        child: Column(children: [
          Expanded(child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: const Color(0xFFF7F8F4), borderRadius: BorderRadius.circular(11)),
            child: AssetPic(
              path: 'assets/brands/${name.toLowerCase()}.png',
              fallback: Center(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: .5, color: ink))),
            ),
          )),
          const SizedBox(height: 6),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: ink, fontWeight: FontWeight.w800, letterSpacing: .35)),
        ]),
      ),
    );
  }
}

// CATEGORY PAGE
class CategoryProductsScreen extends StatelessWidget {
  final String category;
  const CategoryProductsScreen({super.key, required this.category});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context); final list = s.listProducts(category: category); final cats = s.shownCategories;
    return Scaffold(backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: Text(category, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [IconButton(onPressed: () => showSortSheet(context), icon: const Icon(Icons.tune_rounded))]),
      body: Column(children: [
        SizedBox(height: 46, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: cats.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (c, i) { final on = cats[i].name == category;
            return GestureDetector(onTap: on ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: cats[i].name))),
              child: Container(alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: on ? ink : Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: on ? ink : line)),
                child: Text(cats[i].name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? Colors.white : ink))));
          })),
        Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 4), child: Row(children: [
          Text('${list.length} ${list.length == 1 ? 'product' : 'products'}', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(), Text(s.sort, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        Expanded(child: list.isEmpty ? const EmptyState(title: 'No products yet', subtitle: 'Products in this category will appear here.')
          : GridView.builder(padding: const EdgeInsets.fromLTRB(14, 6, 14, 20), itemCount: list.length,
              gridDelegate: productGridDelegate(), itemBuilder: (c, i) => ProductCard(product: list[i], index: i))),
      ]));
  }
}

// SEARCH
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context); final list = s.listProducts(q: controller.text, sortBy: 'Featured');
    return Scaffold(appBar: AppBar(title: const Text('Search products')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: controller, autofocus: true, onChanged: (v) => setState(() {}),
          decoration: InputDecoration(hintText: 'Search products, brands, categories', prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(onPressed: () { controller.clear(); setState(() {}); }, icon: const Icon(Icons.close))))),
        Expanded(child: list.isEmpty ? const EmptyState(title: 'No matches', subtitle: 'Try a different search.', icon: Icons.search_off_rounded)
          : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: list.length, separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) => ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 6), leading: ProductThumb(product: list[i]),
                title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${list[i].brand} · ₹${list[i].price}'), trailing: const Icon(Icons.chevron_right), onTap: () => openProduct(context, list[i])))),
      ]));
  }
}

// NOTIFICATIONS
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  late final StoreController store;
  @override void initState() { super.initState(); store = StoreScope.read(context); WidgetsBinding.instance.addPostFrameCallback((_) => store.markNoticesSeen()); }
  IconData _icon(String k) { switch (k) { case 'order': return Icons.local_shipping_outlined; case 'admin': return Icons.receipt_long_outlined; case 'member': return Icons.workspace_premium_outlined; default: return Icons.notifications_none_rounded; } }
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context); final updates = s.notices.where((n) => n.kind != 'offer').toList(); final offers = s.notifications;
    return Scaffold(appBar: AppBar(title: const Text('Notifications')),
      body: (updates.isEmpty && offers.isEmpty) ? const EmptyState(title: 'No notifications', subtitle: 'Order updates and offers will show up here.', icon: Icons.notifications_none_rounded)
        : ListView(padding: const EdgeInsets.all(16), children: [
          if (updates.isNotEmpty) ...[
            const Text('UPDATES', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(height: 8),
            ...updates.map((n) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)), child: Icon(_icon(n.kind), size: 19)),
                const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 2),
                  Text(n.body, style: const TextStyle(color: muted, fontSize: 12, height: 1.35)),
                  if (n.date.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(shortDate(n.date), style: const TextStyle(color: muted, fontSize: 10))),
                ])),
              ]))),
            const SizedBox(height: 10),
          ],
          if (offers.isNotEmpty) ...[
            const Text('OFFERS', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(height: 8),
            ...List.generate(offers.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: CouponCard(coupon: offers[i], index: i))),
          ],
        ]));
  }
}

class CouponCard extends StatelessWidget {
  final Coupon coupon; final int index;
  const CouponCard({super.key, required this.coupon, this.index = 1});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: softBox(index, radius: 18),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(coupon.label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 2),
        Text(coupon.title.isEmpty ? 'Special offer' : coupon.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), const SizedBox(height: 2),
        Text(coupon.minOrder > 0 ? 'On orders above ₹${coupon.minOrder}' : 'No minimum order', style: const TextStyle(color: muted, fontSize: 11)),
      ])),
      GestureDetector(onTap: () async { await Clipboard.setData(ClipboardData(text: coupon.code)); if (context.mounted) toast(context, 'Code ${coupon.code} copied'); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(coupon.code, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(width: 6), const Icon(Icons.copy_rounded, size: 14)]))),
    ]));
}

// WISHLIST
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context); final list = s.products.where((p) => p.active && s.favourites.contains(p.id)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Saved products')),
      body: list.isEmpty ? const EmptyState(title: 'Nothing saved yet', subtitle: 'Tap the heart on a product to save it.', icon: Icons.favorite_border)
        : GridView.builder(padding: const EdgeInsets.all(14), itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 12, childAspectRatio: .69),
            itemBuilder: (c, i) => ProductCard(product: list[i], index: i)));
  }
}
