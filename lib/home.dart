import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';
import 'cart.dart';
import 'auth.dart';
import 'design.dart';

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
                Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFD5DFCA), borderRadius: BorderRadius.circular(11)),
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
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(0, 12, 0, 4), child: SalePromoBanner())),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Curated Brands', action: 'Explore')),
        SliverToBoxAdapter(child: SizedBox(height: 90,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            children: s.brands.map((b) => _BrandTile(name: b)).toList()),
        )),
        const SliverToBoxAdapter(child: SectionHeading(title: 'New arrivals', action: 'Fresh picks')) ,
        if (products.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 30),
            child: EmptyState(title: 'No products found', subtitle: 'Try another brand or category.')))
        else
          _productRows(products),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Trending now')),
        if (products.isNotEmpty)
          _productRows(products, offset: 1, limit: 4),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Curated for you')),
        if (products.isNotEmpty)
          _productRows(products, offset: 2, limit: 4),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        const SliverToBoxAdapter(child: SectionHeading(title: 'Popular products')),
        if (products.isNotEmpty)
          _productRows(products, offset: products.length ~/ 2, limit: 4, bottom: 24),
      ]),
    );
  }
}


// Amazon-style full-width product rows for mobile screens.
// Mixed product feed: one full-width horizontal card followed by up to two
// compact vertical cards. The layout decision is isolated here so it can later
// be driven by the Admin/advertisement placement settings.
Widget _productRows(List<Product> products, {int offset = 0, int? limit, double bottom = 10}) {
  final count = limit == null || limit > products.length ? products.length : limit;
  final groups = (count / 3).ceil();
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(14, 0, 14, bottom),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, groupIndex) {
          final first = groupIndex * 3;
          final remaining = count - first;
          final firstProduct = products[(first + offset) % products.length];
          final verticalCount = remaining - 1 >= 2 ? 2 : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              ProductCard(product: firstProduct, index: first + offset, horizontal: true),
              if (verticalCount > 0) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(verticalCount, (slot) {
                  final itemIndex = first + 1 + slot;
                  return Expanded(child: Padding(
                    padding: EdgeInsets.only(left: slot == 0 ? 0 : 5, right: slot == 0 ? 5 : 0),
                    child: ProductCard(
                      product: products[(itemIndex + offset) % products.length],
                      index: itemIndex + offset,
                      horizontal: false,
                    ),
                  ));
                })),
              ] else if (remaining == 2) ...[
                const SizedBox(height: 10),
                ProductCard(
                  product: products[(first + 1 + offset) % products.length],
                  index: first + 1 + offset,
                  horizontal: true,
                ),
              ],
            ]),
          );
        },
        childCount: groups,
      ),
    ),
  );
}

class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onTap;
  _StickySearchDelegate({required this.onTap});
  @override double get minExtent => 64;
  @override double get maxExtent => 64;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
    decoration: const BoxDecoration(color: Color(0xFFF8F8F5)),
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
    child: Material(
      color: const Color(0xFFFFFFFF), elevation: 0,
      shadowColor: Colors.transparent, borderRadius: BorderRadius.circular(25),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(25),
        child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.white,
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 23, color: Color(0xFF30352D)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Search for products, brands...', style: TextStyle(color: Color(0xFF8A8E85), fontSize: 13, fontWeight: FontWeight.w500))),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showSortSheet(context),
              child: const Padding(padding: EdgeInsets.only(left: 10), child: Icon(Icons.tune_rounded, size: 22, color: Color(0xFF30352D))),
            ),
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
    timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !controller.hasClients) return;
      final n = StoreScope.read(context).banners.length;
      if (n < 2) return;
      controller.animateToPage((page + 1) % n, duration: const Duration(milliseconds: 650), curve: Curves.easeInOut);
    });
  }
  @override
  void dispose() { timer?.cancel(); controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final list = s.banners.isEmpty
        ? <BannerItem>[BannerItem(tag: 'New', title: 'Discover your\neveryday style', button: 'Shop Now')]
        : s.banners;
    final current = page >= list.length ? 0 : page;
    return SizedBox(
      height: 176,
      child: PageView.builder(
        controller: controller,
        itemCount: list.length,
        onPageChanged: (v) => setState(() => page = v),
        itemBuilder: (c, i) {
          final b = list[i];
          return PromoBannerCard(
            tag: b.tag, title: b.title, button: b.button.isEmpty ? 'Shop Now' : b.button, image: b.image,
            count: list.length, active: current,
            onTap: () {
              if (b.category.isNotEmpty) {
                openCategory(context, b.category);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              }
            },
          );
        },
      ),
    );
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
    return GestureDetector(onTap: () => s.setBrand(active ? 'All' : name),
      child: SizedBox(width: 72, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 58, height: 56, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? accentOf(context) : const Color(0xFFE8E8E4)),
              boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 7, offset: Offset(0, 2))]),
            padding: const EdgeInsets.all(7),
            child: AssetPic(path: 'assets/brands/${name.toLowerCase()}.png',
              fallback: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ink)))),
          const SizedBox(height: 5),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: const Color(0xFF333333))),
        ]))));
  }
}

class SalePromoBanner extends StatefulWidget {
  const SalePromoBanner({super.key});
  @override
  State<SalePromoBanner> createState() => _SalePromoBannerState();
}

class _SalePromoBannerState extends State<SalePromoBanner> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final secs = d.inSeconds < 0 ? 0 : d.inSeconds;
    final days = secs ~/ 86400;
    final h = ((secs % 86400) ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    return days > 0 ? '${days}d $h:$m:$sec' : '$h : $m : $sec';
  }

  @override
  Widget build(BuildContext context) {
    final st = StoreScope.of(context).settings;
    if (!st.saleEnabled) return const SizedBox.shrink();
    final endAt = DateTime.tryParse(st.saleEndAt)?.toLocal();
    if (endAt != null && endAt.isBefore(DateTime.now())) return const SizedBox.shrink();
    final hasImg = st.saleBgImage.trim().isNotEmpty;
    final custom = _hex(st.saleBgColor);
    final base = custom ?? kBrandGreen;
    // text colour: white on image / dark colours, black on light colours
    final fg = (hasImg || base.computeLuminance() < .45) ? Colors.white : Colors.black;
    final fgSoft = fg == Colors.white ? const Color(0xCCFFFFFF) : Colors.black87;
    final btnBg = fg == Colors.white ? Colors.white : Colors.black;
    final btnFg = fg == Colors.white ? Colors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: custom != null
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base, base])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB9E277), kBrandGreen, Color(0xFFA9D96A)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x1A263321), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: Stack(children: [
        if (hasImg) Positioned.fill(child: NetImage(url: st.saleBgImage, fit: BoxFit.cover, fallback: const SizedBox.shrink())),
        if (hasImg) Positioned.fill(child: Container(color: const Color(0x66000000))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: (fg == Colors.white ? Colors.white24 : Colors.white.withOpacity(.55)), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_fire_department_rounded, color: fg == Colors.white ? Colors.white : Colors.black, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(st.saleTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg))),
          FilledButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            style: FilledButton.styleFrom(
              backgroundColor: btnBg, foregroundColor: btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Shop the Sale', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              SizedBox(width: 5), Icon(Icons.north_east, size: 13),
            ]),
          ),
        ]),
        const SizedBox(height: 15),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FLAT', style: TextStyle(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: fgSoft)),
            const SizedBox(height: 2),
            Text(st.saleOffer, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 30, height: 1, letterSpacing: -.8, fontWeight: FontWeight.w900, color: fg)),
          ])),
          if (endAt != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(color: fg == Colors.white ? const Color(0x55000000) : Colors.black, borderRadius: BorderRadius.circular(13)),
              child: Column(children: [
                const Text('ENDS IN', style: TextStyle(color: Color(0xFFD7E8BE), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(_fmt(endAt.difference(DateTime.now())), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
            ),
        ]),
        if (st.saleNote.isNotEmpty) ...[
          const SizedBox(height: 13),
          Row(children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: fgSoft, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Expanded(child: Text(st.saleNote, style: TextStyle(fontSize: 10, color: fgSoft, fontWeight: FontWeight.w700))),
            Icon(Icons.bolt_rounded, size: 16, color: fgSoft),
          ]),
        ],
      ])),
      ]),
    );
  }

  Color? _hex(String v) {
    var h = v.trim().replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final n = int.tryParse(h, radix: 16);
    return n == null ? null : Color(n);
  }
}

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
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (c, i) => ProductCard(product: list[i], index: i),
            )),
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final matches = store.listProducts(
      q: controller.text,
      sortBy: 'Featured',
    );
    final hasQuery = controller.text.trim().isNotEmpty;
    final products = matches.isEmpty && hasQuery
        ? store.listProducts(sortBy: 'Top Rated').take(8).toList()
        : matches;

    return Scaffold(
      appBar: AppBar(title: const Text('Search products')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search products, brands, categories',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {
                    controller.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const EmptyState(
                    title: 'No products yet',
                    subtitle: 'Products will appear here.',
                    icon: Icons.search_off_rounded,
                  )
                : Column(
                    children: [
                      if (matches.isEmpty && hasQuery)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'No exact match — you may like these',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              leading: ProductThumb(product: product),
                              title: Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text('${product.brand} · ₹${product.price}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => openProduct(context, product),
                            );
                          },
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
        : ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (c, i) => ProductCard(product: list[i], index: i),
          ));
  }
}
