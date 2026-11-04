import 'package:flutter/material.dart';
import 'account.dart';
import 'auth.dart';
import 'cart.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});
  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PageController pager = PageController();
  int page = 0;
  String size = '';
  String color = '';
  bool subscribe = false; // Subscribe & Save (only offered when admin enables it)
  int subDays = 0;

  @override
  void initState() {
    super.initState();
    // Default selection: Medium (or the middle size) and first colour,
    // so "Buy now" works with one tap. User can still pick another.
    final sizes = widget.product.sizes;
    if (sizes.isNotEmpty) {
      final idx = sizes.indexWhere((x) {
        final v = x.trim().toLowerCase();
        return v == 'm' || v == 'medium';
      });
      size = idx >= 0 ? sizes[idx] : sizes[sizes.length ~/ 2];
    }
    final colors = widget.product.colors;
    if (colors.isNotEmpty) color = colors.first;
  }

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ small parts
  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(height: 1),
          const SizedBox(height: 18),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _accordion(String title, Widget child, {bool initiallyExpanded = false}) => Column(children: [
        Divider(height: 1, color: Colors.grey.shade200),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
            trailing: const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: ink),
            children: [child],
          ),
        ),
      ]);

  Widget _label(String t, String chosen) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(children: [
          Text('$t:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          if (chosen.isNotEmpty) Text('  $chosen', style: const TextStyle(fontSize: 14, color: muted)),
        ]),
      );

  Widget _chips(List<String> items, String selected, void Function(String) onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((x) {
        final on = x == selected;
        return GestureDetector(
          onTap: () => onPick(x),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minWidth: 46, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? const Color(0xFFFF7A3D) : const Color(0xFFF2F2F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(x, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: on ? Colors.white : ink)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _perk(IconData icon, String text) => Expanded(
        child: Column(children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.25)),
        ]),
      );

  bool _pickedOptions(Product p) {
    if (p.sizes.isNotEmpty && size.isEmpty) {
      toast(context, 'Please select a size');
      return false;
    }
    if (p.colors.isNotEmpty && color.isEmpty) {
      toast(context, 'Please select a colour');
      return false;
    }
    return true;
  }

  int _chosenDays(StoreController s) {
    if (!subscribe || !s.settings.subEnabled) return 0;
    final opts = s.settings.subDayOptions;
    if (opts.isEmpty) return 0;
    return opts.contains(subDays) ? subDays : (opts.contains(30) ? 30 : opts.first);
  }

  Future<void> _addToCart(StoreController s, Product p) async {
    if (!_pickedOptions(p)) return;
    await s.addToCart(p.id, size: size, color: color, subDays: _chosenDays(s));
    if (mounted) toast(context, 'Added to cart');
  }

  /// Buy now = sirf ye ek product, cart me kuch add nahi hota
  Future<void> _buyNow(StoreController s, Product p) async {
    if (!_pickedOptions(p)) return;
    if (!await ensureLogin(context)) return;
    s.startBuyNow(p.id, size: size, color: color, subDays: _chosenDays(s));
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen(buyNow: true)));
    s.endBuyNow();
  }

  Future<void> _writeReview(StoreController s, Product p) async {
    int rating = 5;
    final text = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rate this product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setS(() => rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 34, color: const Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: text, maxLines: 3, decoration: const InputDecoration(hintText: 'Share your experience with this product')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final err = await s.addReview(p.id, rating, text.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (mounted) toast(context, err ?? 'Thanks for your review!');
                },
                child: const Text('Submit review'),
              ),
            ),
          ]),
        ),
      ),
    );
    text.dispose();
  }

  // ------------------------------------------------------------ purchase options
  Widget _purchaseOptions(StoreController s, Product p) {
    final st = s.settings;
    final days = _chosenDays(s) == 0 ? (st.subDayOptions.contains(30) ? 30 : st.subDayOptions.first) : _chosenDays(s);
    final subPrice = p.price * (100 - st.subPct) ~/ 100;
    const orange = Color(0xFFE5532D);
    Widget radio(bool on) => Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: on ? orange : const Color(0xFFA1A1AA), size: 22);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(top: 22, bottom: 12), child: Text('Purchase options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      GestureDetector(
        onTap: () => setState(() => subscribe = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: !subscribe ? Colors.black : line, width: !subscribe ? 1.4 : 1)),
          child: Row(children: [
            radio(!subscribe),
            const SizedBox(width: 10),
            const Expanded(child: Text('One-time purchase', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Text('₹${p.price}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => setState(() { subscribe = true; subDays = days; }),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: subscribe ? const Color(0xFFFFF5F2) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: subscribe ? const Color(0xFFFF7A3D) : line, width: subscribe ? 1.4 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              radio(subscribe),
              const SizedBox(width: 10),
              const Text('Subscribe & Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFF5A36), borderRadius: BorderRadius.circular(8)),
                child: Text('SAVE ${st.subPct}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 10),
            Divider(height: 1, color: orange.withOpacity(.18)),
            const SizedBox(height: 10),
            Row(children: [
              Text('₹$subPrice', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: orange)),
              const SizedBox(width: 14),
              const Text('Deliver every', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: st.subDayOptions.contains(days) ? days : st.subDayOptions.first,
                    isDense: true,
                    style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w600),
                    items: st.subDayOptions.map((d) => DropdownMenuItem<int>(value: d, child: Text('$d days'))).toList(),
                    onChanged: (v) => setState(() { subscribe = true; subDays = v ?? days; }),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('Save ${st.subPct}%  ·  Cancel anytime via support', style: const TextStyle(fontSize: 11.5, color: orange, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 10, left: 4),
        child: Row(children: [
          Icon(Icons.lock_outline_rounded, size: 15, color: muted),
          SizedBox(width: 6),
          Text('Secure, flexible, and hassle-free', style: TextStyle(fontSize: 12, color: muted)),
        ]),
      ),
    ]);
  }

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = s.productById(widget.product.id) ?? widget.product;
    final fav = s.favourites.contains(p.id);
    final rating = s.ratingOf(p.id);
    final revs = s.reviewsOf(p.id);
    final imgCount = p.images.isEmpty ? 1 : p.images.length;
    final days = s.etaDays;
    final inStock = p.stock > 0;
    final subOn = s.settings.subEnabled && s.settings.subDayOptions.isNotEmpty;
    final chosen = _chosenDays(s);
    final shownPrice = chosen > 0 ? p.price * (100 - s.settings.subPct) ~/ 100 : p.price;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            icon: Badge(isLabelVisible: s.itemCount > 0, label: Text('${s.itemCount}'), child: const Icon(Icons.shopping_bag_outlined)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            // ---- gallery (image fills the rounded frame)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(fit: StackFit.expand, children: [
                  PageView.builder(
                    controller: pager,
                    itemCount: imgCount,
                    onPageChanged: (v) => setState(() => page = v),
                    itemBuilder: (c, i) => NetImage(
                      url: p.images.isEmpty ? '' : p.images[i],
                      fit: BoxFit.cover,
                      fallback: Container(color: const Color(0xFFF5F5F5), child: iconFallback(s.iconKeyFor(p.category), size: 90)),
                    ),
                  ),
                  if (p.discount > 0)
                    Positioned(
                      left: 12, top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
                        child: Text('${p.discount}% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  Positioned(
                    right: 12, top: 12,
                    child: Material(
                      color: Colors.white, shape: const CircleBorder(), elevation: 2, shadowColor: const Color(0x33000000),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => s.toggleFavourite(p.id),
                        child: Padding(padding: const EdgeInsets.all(9), child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 20, color: fav ? const Color(0xFFE11D48) : ink)),
                      ),
                    ),
                  ),
                  if (imgCount > 1)
                    Positioned(
                      left: 0, right: 0, bottom: 13,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(imgCount, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: page == i ? 18 : 6, height: 6,
                        decoration: BoxDecoration(color: page == i ? Colors.black : Colors.white70, borderRadius: BorderRadius.circular(8)),
                      ))),
                    ),
                ]),
              ),
            ),
            if (imgCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imgCount,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (c, i) => GestureDetector(
                      onTap: () => pager.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                      child: Container(
                        width: 58,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: i == page ? Colors.black : Colors.transparent, width: 1.6),
                        ),
                        child: NetImage(url: p.images[i], fallback: iconFallback(s.iconKeyFor(p.category), size: 20)),
                      ),
                    ),
                  ),
                ),
              ),

            // ---- title + price
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(p.category.isNotEmpty ? p.category : p.brand, style: const TextStyle(color: muted, fontSize: 12.5))),
              if (rating > 0) ...[
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFF7A3D)),
                const SizedBox(width: 3),
                Text('(${rating.toStringAsFixed(1)})', style: const TextStyle(color: muted, fontSize: 12.5)),
              ] else
                const Text('No reviews yet', style: TextStyle(color: muted, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2))),
              const SizedBox(width: 12),
              Text('₹$shownPrice', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            if (p.mrp > shownPrice)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('₹${p.mrp}', style: const TextStyle(color: muted, fontSize: 12.5, decoration: TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  Text('${((p.mrp - shownPrice) * 100 / p.mrp).round()}% off', style: const TextStyle(color: success, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(!inStock ? Icons.cancel_outlined : Icons.check_circle_outline, size: 15, color: !inStock ? danger : (p.stock <= 5 ? const Color(0xFFD97706) : success)),
              const SizedBox(width: 6),
              Text(
                !inStock ? 'Out of stock' : (p.stock <= 5 ? 'Only ${p.stock} left' : 'In stock'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: !inStock ? danger : (p.stock <= 5 ? const Color(0xFFD97706) : success)),
              ),
              if (inStock) Text('  ·  Delivery by ${dateAfter(days)}', style: const TextStyle(fontSize: 12.5, color: muted)),
            ]),

            // ---- options
            if (p.sizes.isNotEmpty) ...[_label('Size', size), _chips(p.sizes, size, (v) => setState(() => size = v))],
            if (p.colors.isNotEmpty) ...[_label('Colour', color), _chips(p.colors, color, (v) => setState(() => color = v))],

            // ---- Subscribe & Save (admin controlled)
            if (subOn) _purchaseOptions(s, p),

            // ---- trust row
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _perk(Icons.autorenew_rounded, '7-day easy\nreturns'),
                _perk(Icons.verified_user_outlined, 'Secure\npayments'),
                _perk(Icons.inventory_2_outlined, '100% genuine\nproducts'),
              ]),
            ),

            // ---- accordions
            const SizedBox(height: 8),
            _accordion('Description', Text(p.description.isEmpty ? 'No details added yet.' : p.description, style: const TextStyle(color: Color(0xFF4B5563), height: 1.6, fontSize: 13)), initiallyExpanded: true),
            _accordion(
              'Free Delivery and Returns',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 19),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.pincode.isEmpty ? 'Add your PIN code to check delivery' : 'Deliver to ${s.city.isEmpty ? '' : '${s.city} - '}${s.pincode}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                  TextButton(onPressed: () => showPinSheet(context), child: Text(s.pincode.isEmpty ? 'Add' : 'Change')),
                ]),
                Row(children: [
                  Icon(s.isMember ? Icons.bolt_rounded : Icons.local_shipping_outlined, size: 19),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.isMember ? 'Express delivery by ${dateAfter(days)}' : 'Delivery by ${dateAfter(days)}', style: const TextStyle(fontSize: 13))),
                  Text(s.isMember ? 'FREE' : (s.normalShipping == 0 ? 'FREE' : '₹${s.settings.shippingFee}'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: (s.isMember || s.normalShipping == 0) ? success : ink)),
                ]),
                const SizedBox(height: 10),
                const Row(children: [Icon(Icons.payments_outlined, size: 19), SizedBox(width: 10), Text('Cash on Delivery & online payment', style: TextStyle(fontSize: 13))]),
                const SizedBox(height: 12),
                Text(s.settings.returnPolicy, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12.5, height: 1.55)),
              ]),
            ),
            _accordion(
              'Specifications',
              Column(children: [
                _specRow('SKU', p.sku.isEmpty ? '-' : p.sku, false),
                _specRow('Category', p.category, true),
                ...List.generate(p.specs.length, (i) {
                  final e = p.specs.entries.elementAt(i);
                  return _specRow(e.key, e.value, true);
                }),
              ]),
            ),
            if (p.brand.isNotEmpty)
              _accordion('About ${p.brand}', Text(p.aboutBrand.isEmpty ? 'Brand information will be added soon.' : p.aboutBrand, style: const TextStyle(color: Color(0xFF4B5563), height: 1.6, fontSize: 13))),
            _accordion('See Reviews (${revs.length})', _reviews(s, p, rating, revs), initiallyExpanded: revs.isNotEmpty),
          ]),
        ),

        // ---- bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              GestureDetector(
                onTap: () => s.toggleFavourite(p.id),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: const Color(0xFFF2F2F4), borderRadius: BorderRadius.circular(25)),
                  child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 22, color: fav ? const Color(0xFFE11D48) : ink),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(0, 50), shape: const StadiumBorder()),
                  onPressed: inStock ? () => _addToCart(s, p) : null,
                  child: const FittedBox(child: Text('Add to cart', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Colors.black, width: 1.2), minimumSize: const Size(0, 50), shape: const StadiumBorder()),
                  onPressed: inStock ? () => _buyNow(s, p) : null,
                  child: FittedBox(child: Text(inStock ? 'Buy it now' : 'Out of stock', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _reviews(StoreController s, Product p, double rating, List<Review> revs) {
    final counts = List.generate(5, (i) => revs.where((r) => r.rating == 5 - i).length);
    final ac = accentOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (revs.isNotEmpty)
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(children: [
            Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1)),
            const SizedBox(height: 6),
            StarRow(rating: rating, size: 16),
            const SizedBox(height: 4),
            Text('${revs.length} ${revs.length == 1 ? 'review' : 'reviews'}', style: const TextStyle(color: muted, fontSize: 11)),
          ]),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final frac = revs.isEmpty ? 0.0 : counts[i] / revs.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Text('${5 - i}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: line, color: ac),
                      ),
                    ),
                  ]),
                );
              }),
            ),
          ),
        ])
      else
        const Text('No reviews yet.', style: TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 14),
      // sirf order karne wale review likh sakte hain
      if (s.canReview(p.id))
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(onPressed: () => _writeReview(s, p), icon: const Icon(Icons.rate_review_outlined, size: 18), label: const Text('Write a review')),
        )
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(s.hasReviewed(p.id) ? Icons.check_circle_outline : Icons.lock_outline, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.hasReviewed(p.id) ? 'You have reviewed this product. Thank you!' : 'Only customers who have ordered this product can write a review.',
              style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
          ),
        ]),
      if (revs.isNotEmpty) const SizedBox(height: 6),
      ...revs.map((r) => Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE5EBDD),
                  child: Text(r.name.isEmpty ? '?' : r.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF34432D))),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(shortDate(r.date).split('  ').first, style: const TextStyle(color: muted, fontSize: 10)),
                ])),
                StarRow(rating: r.rating.toDouble(), size: 13),
              ]),
              if (r.text.isNotEmpty) ...[const SizedBox(height: 9), Text(r.text, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF4B5563)))],
              const SizedBox(height: 4),
              const Row(children: [
                Icon(Icons.verified_outlined, size: 13, color: success),
                SizedBox(width: 4),
                Text('Verified purchase', style: TextStyle(color: success, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
            ),
          )),
    ]);
  }

  Widget _specRow(String k, String v, bool top) => Container(
        decoration: BoxDecoration(border: top ? Border(top: BorderSide(color: line)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(k, style: const TextStyle(color: muted, fontSize: 13))),
          Expanded(flex: 5, child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      );
}
