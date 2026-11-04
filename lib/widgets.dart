import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'product.dart';

Color accentOf(BuildContext context) => Theme.of(context).colorScheme.primary;
Future<void> openUrl(String url) async { try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {} }
void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

const ColorFilter kDarkFilter = ColorFilter.matrix(<double>[
  0.574, -1.430, -0.144, 0, 255, -0.426, -0.430, -0.144, 0, 255,
  -0.426, -1.430, 0.856, 0, 255, 0, 0, 0, 1, 0,
]);
Widget keepColors(BuildContext context, Widget child) =>
    StoreScope.of(context).dark ? ColorFiltered(colorFilter: kDarkFilter, child: child) : child;

class NetImage extends StatelessWidget {
  final String url; final Widget fallback; final BoxFit fit;
  const NetImage({super.key, required this.url, required this.fallback, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return fallback;
    return keepColors(context, Image.network(url.trim(), fit: fit, width: double.infinity, height: double.infinity,
      errorBuilder: (_, __, ___) => keepColors(context, fallback),
      loadingBuilder: (c, child, p) => p == null ? child : keepColors(context, const ColoredBox(color: Color(0xFFF1F3F5)))));
  }
}
class AssetPic extends StatelessWidget {
  final String path; final Widget fallback; final BoxFit fit;
  const AssetPic({super.key, required this.path, required this.fallback, this.fit = BoxFit.contain});
  @override Widget build(BuildContext context) => keepColors(context, Image.asset(path, fit: fit, errorBuilder: (_, __, ___) => keepColors(context, fallback)));
}
class BrandLogo extends StatelessWidget {
  final double size; const BrandLogo({super.key, this.size = 42});
  @override Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final letter = Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(color: accentOf(context), borderRadius: BorderRadius.circular(size * .28)),
      child: Text(s.settings.appName.isEmpty ? 'Z' : s.settings.appName[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontSize: size * .48, fontWeight: FontWeight.w900)));
    final remoteLogo = s.settings.logoUrl.trim().isNotEmpty ? s.settings.logoUrl.trim() : AppConfig.logoUrl;
    Widget? img;
    if (remoteLogo.isNotEmpty) { img = NetImage(url: remoteLogo, fit: BoxFit.contain, fallback: letter); }
    else if (AppConfig.logoAsset.isNotEmpty) { img = AssetPic(path: AppConfig.logoAsset, fallback: letter); }
    if (img == null) return letter;
    return SizedBox(width: size, height: size, child: ClipRRect(borderRadius: BorderRadius.circular(size * .22), child: img));
  }
}
Widget iconFallback(String iconKey, {double size = 54}) => Center(child: Icon(iconFor(iconKey), size: size, color: const Color(0x99000000)));

class ProductThumb extends StatelessWidget {
  final Product product; const ProductThumb({super.key, required this.product});
  @override Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Container(width: 72, height: 78, clipBehavior: Clip.antiAlias, decoration: softBox(product.id, radius: 14),
      child: NetImage(url: product.images.isEmpty ? '' : product.images.first, fallback: iconFallback(s.iconKeyFor(product.category), size: 30)));
  }
}
class SectionHeading extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onTap;
  const SectionHeading({super.key, required this.title, this.action, this.onTap});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 22, 12, 10),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -.3))),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!, style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700))),
    ]));
}
class EmptyState extends StatelessWidget {
  final String title, subtitle; final IconData icon;
  const EmptyState({super.key, required this.title, required this.subtitle, this.icon = Icons.shopping_bag_outlined});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72, decoration: softBox(3, radius: 36), child: Icon(icon, size: 30, color: muted)),
      const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
    ])));
}
class PriceRow extends StatelessWidget {
  final String label, value; final bool bold; final Color? color;
  const PriceRow({super.key, required this.label, required this.value, this.bold = false, this.color});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: bold ? ink : muted, fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w500))),
      Text(value, style: TextStyle(color: color ?? ink, fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700)),
    ]));
}
class QtyButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const QtyButton({super.key, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16)));
}
class StarRow extends StatelessWidget {
  final double rating; final double size;
  const StarRow({super.key, required this.rating, this.size = 15});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(rating >= i + 1 ? Icons.star_rounded : (rating >= i + .5 ? Icons.star_half_rounded : Icons.star_outline_rounded), size: size, color: const Color(0xFFF59E0B))));
}
class StatusChip extends StatelessWidget {
  final String status; const StatusChip(this.status, {super.key});
  @override Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withAlpha(28), borderRadius: BorderRadius.circular(30)),
      child: Text(status, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)));
  }
}
class OrderProgress extends StatelessWidget {
  final String status; const OrderProgress(this.status, {super.key});
  @override Widget build(BuildContext context) {
    if (status == 'Cancelled') return const Row(children: [Icon(Icons.cancel_outlined, size: 16, color: danger), SizedBox(width: 6), Text('This order was cancelled', style: TextStyle(color: danger, fontSize: 12, fontWeight: FontWeight.w700))]);
    final idx = orderSteps.indexOf(status); final ac = accentOf(context);
    return Row(children: List.generate(orderSteps.length, (i) => Expanded(child: Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: i <= idx ? ac : const Color(0x22000000), borderRadius: BorderRadius.circular(5))))));
  }
}

void openProduct(BuildContext context, Product p) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));

class ProductCard extends StatelessWidget {
  final Product product;
  final int index;
  const ProductCard({super.key, required this.product, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = product;
    final fav = store.favourites.contains(p.id);
    final out = p.stock <= 0;
    final rating = store.ratingOf(p.id);
    final hasImg = p.images.isNotEmpty && p.images.first.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () => openProduct(context, p),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 204,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE9E9E6)),
            boxShadow: const [
              BoxShadow(color: Color(0x09000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Compact image panel, similar to the supplied shopping-list reference.
              Expanded(
                flex: 40,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF4F4F2),
                      padding: const EdgeInsets.all(10),
                      child: hasImg
                          ? NetImage(
                              url: p.images.first,
                              fit: BoxFit.contain,
                              fallback: iconFallback(store.iconKeyFor(p.category), size: 42),
                            )
                          : iconFallback(store.iconKeyFor(p.category), size: 42),
                    ),
                    if (p.discount > 0)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4E684),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${p.discount}% OFF',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF242424)),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => store.toggleFavourite(p.id),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 19,
                              color: fav ? const Color(0xFFE35D58) : const Color(0xFF242424),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (out)
                      Container(
                        color: const Color(0x99FFFFFF),
                        alignment: Alignment.center,
                        child: const Text('OUT OF STOCK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
              ),
              Expanded(
                flex: 60,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.brand.isNotEmpty ? p.brand.toUpperCase() : (p.category.isNotEmpty ? p.category.toUpperCase() : 'FEATURED'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, letterSpacing: .7, color: Color(0xFF777777), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          p.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, height: 1.22, fontWeight: FontWeight.w600, color: Color(0xFF242424)),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF07822)),
                          const SizedBox(width: 2),
                          Text(rating > 0 ? rating.toStringAsFixed(1) : 'New', style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          const Expanded(child: Text('Customer rating', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Color(0xFF888888)))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${p.price}', style: const TextStyle(fontSize: 19, height: 1, fontWeight: FontWeight.w900, color: Color(0xFF242424))),
                          if (p.mrp > p.price) ...[
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 1),
                              child: Text('₹${p.mrp}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888), decoration: TextDecoration.lineThrough)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: FilledButton(
                          onPressed: out ? null : () async {
                            await store.addToCart(p.id);
                            if (context.mounted) toast(context, '${p.name} added to cart');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD4E684),
                            disabledBackgroundColor: const Color(0xFFE7E7E4),
                            foregroundColor: const Color(0xFF242424),
                            disabledForegroundColor: const Color(0xFF777777),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          ),
                          child: Text(out ? 'Unavailable' : 'Add to cart', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Retained for any other screen that still uses a two-column product grid.
SliverGridDelegate productGridDelegate() =>
    const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 12, mainAxisExtent: 252);

class FooterBlock extends StatelessWidget {
  const FooterBlock({super.key});
  @override Widget build(BuildContext context) {
    final st = StoreScope.of(context).settings;
    return Container(margin: const EdgeInsets.fromLTRB(14, 8, 14, 20), padding: const EdgeInsets.all(16),
      decoration: softBox(0, radius: 20), child: Column(children: [
        Text(st.appName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
        const SizedBox(height: 4), Text(st.tagline, style: const TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 4, children: st.footerLinks.map((l) => TextButton(
          onPressed: () => openUrl(l['url'] ?? ''), style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: Text(l['label'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))).toList()),
        const SizedBox(height: 4), Text(st.footerText, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 10)),
      ]));
  }
}

Future<void> showSortSheet(BuildContext context) async {
  final s = StoreScope.read(context);
  final value = await showModalBottomSheet<String>(context: context, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(18), child: Text('Sort products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      ...['Featured', 'Price: Low to High', 'Price: High to Low', 'Top Rated'].map((x) => ListTile(title: Text(x), trailing: s.sort == x ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(c, x))),
      const SizedBox(height: 10),
    ])));
  if (value != null) s.setSort(value);
}

Future<void> showPinSheet(BuildContext context) async {
  final s = StoreScope.read(context); final c = TextEditingController(text: s.pincode); String msg = ''; bool busy = false;
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Delivery location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4), const Text('Enter your PIN code to check delivery.', style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 14),
        TextField(controller: c, keyboardType: TextInputType.number, maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN code', prefixIcon: Icon(Icons.pin_drop_outlined), counterText: '')),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg, style: const TextStyle(color: muted, fontSize: 12))),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () async {
          final pin = c.text.trim();
          if (pin.length != 6) { setS(() => msg = 'Enter a valid 6 digit PIN code'); return; }
          setS(() => busy = true); await s.setPin(pin); if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(busy ? 'Checking...' : 'Save PIN code'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : () async {
          setS(() { busy = true; msg = 'Detecting your location...'; });
          final ok = await s.autoDetectPin(); if (!ctx.mounted) return;
          setS(() { busy = false; if (ok) c.text = s.pincode; msg = ok ? 'Detected ${s.city} - ${s.pincode}. Tap Save or edit it.' : 'Could not detect. Please type your PIN code.'; });
        }, icon: const Icon(Icons.my_location_outlined, size: 18), label: const Text('Auto-detect my PIN code'))),
      ]))));
}

class FieldSpec {
  final String label, initial; final TextInputType type; final int lines; final int? maxLen; final bool required; final String? Function(String)? check;
  const FieldSpec(this.label, {this.initial = '', this.type = TextInputType.text, this.lines = 1, this.maxLen, this.required = true, this.check});
}
Future<void> showFieldsSheet(BuildContext context, {required String title, required List<FieldSpec> fields,
  required Future<void> Function(List<String>) onSave, String saveLabel = 'Save'}) async {
  final ctrls = fields.map((f) => TextEditingController(text: f.initial)).toList(); String err = '';
  await showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 14),
        for (var i = 0; i < fields.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: TextField(controller: ctrls[i], keyboardType: fields[i].type, maxLines: fields[i].lines, maxLength: fields[i].maxLen,
            decoration: InputDecoration(labelText: fields[i].label, counterText: ''))),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err, style: const TextStyle(color: danger, fontSize: 12))),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          final vals = ctrls.map((x) => x.text.trim()).toList();
          for (var i = 0; i < fields.length; i++) {
            final f = fields[i];
            if (f.required && vals[i].isEmpty) { setS(() => err = '${f.label} is required'); return; }
            if (vals[i].isNotEmpty && f.check != null) { final m = f.check!(vals[i]); if (m != null) { setS(() => err = m); return; } }
          }
          await onSave(vals); if (ctx.mounted) Navigator.pop(ctx);
        }, child: Text(saveLabel))),
      ])))));
}
String? phoneCheck(String v) => RegExp(r'^\d{10}$').hasMatch(v) ? null : 'Enter a valid 10 digit mobile number';
String? pinCheck(String v) => RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Enter a valid 6 digit PIN code';
