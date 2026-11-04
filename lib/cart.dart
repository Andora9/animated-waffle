import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'cloud.dart';
import 'widgets.dart';
import 'account.dart';
import 'auth.dart';
import 'config.dart';
import 'pay.dart';
import 'design.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final code = TextEditingController();
  String couponMsg = '';

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _remove(StoreController s, CartLine l) async {
    final copy = CartLine(pid: l.pid, size: l.size, color: l.color, qty: l.qty, subDays: l.subDays);
    await s.setQty(l, 0);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Item removed'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'UNDO', onPressed: () => s.restoreLine(copy)),
      ));
  }

  Future<void> _apply(StoreController s, String c) async {
    final r = await s.applyCoupon(c);
    if (!mounted) return;
    setState(() => couponMsg = r ?? '');
    if (r == null) code.clear();
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool primary = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: primary ? const Color(0xFFD4E684) : const Color(0xFFE4E4E7), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: primary ? Colors.white : ink),
        ),
      );

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: padding,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEDEEF1))),
        child: child,
      );

  Widget _line(StoreController s, CartLine l) {
    final p = s.productById(l.pid)!;
    final unit = s.unitPrice(l);
    final low = p.stock > 0 && p.stock <= 5;
    final tags = <String>[
      if (l.size.isNotEmpty) 'Size ${l.size}',
      if (l.color.isNotEmpty) l.color,
    ];
    return Dismissible(
      key: ValueKey(l.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _remove(s, l),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F6), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE5532D)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF8F8F6), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAEAE6))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => openProduct(context, p),
            child: Container(
              width: 84, height: 96, clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: NetImage(url: p.images.isEmpty ? '' : p.images.first, fit: BoxFit.cover, fallback: iconFallback(s.iconKeyFor(p.category), size: 30)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2))),
                GestureDetector(
                  onTap: () => _remove(s, l),
                  child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close_rounded, size: 18, color: muted)),
                ),
              ]),
              if (p.brand.isNotEmpty) Text(p.brand, style: const TextStyle(color: muted, fontSize: 11)),
              if (tags.isNotEmpty || l.subDays > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(spacing: 5, runSpacing: 4, children: [
                    for (final tg in tags)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: line)),
                        child: Text(tg, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    if (l.subDays > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF8F8F6), borderRadius: BorderRadius.circular(6)),
                        child: Text('Every ${l.subDays} days', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFE5532D))),
                      ),
                  ]),
                ),
              if (low) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Only ${p.stock} left', style: const TextStyle(color: Color(0xFFD97706), fontSize: 10.5, fontWeight: FontWeight.w800))),
              const SizedBox(height: 8),
              Row(children: [
                _qtyBtn(Icons.remove, () => l.qty <= 1 ? _remove(s, l) : s.setQty(l, l.qty - 1)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))),
                _qtyBtn(Icons.add, () {
                  if (l.qty >= p.stock) {
                    toast(context, 'Only ${p.stock} available');
                  } else {
                    s.setQty(l, l.qty + 1);
                  }
                }, primary: true),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${unit * l.qty}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  if (p.mrp > unit) Text('₹${p.mrp * l.qty}', style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 10.5, decoration: TextDecoration.lineThrough)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _freeShipCard(StoreController s) {
    final st = s.settings;
    final free = s.shipping == 0;
    final need = st.freeShipAbove - s.subtotal;
    final progress = st.freeShipAbove <= 0 ? 1.0 : (s.subtotal / st.freeShipAbove).clamp(0.0, 1.0);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(free ? Icons.check_circle_rounded : Icons.local_shipping_outlined, size: 20, color: free ? success : ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.isMember ? 'Member perk: FREE & faster delivery' : (free ? 'You have unlocked FREE delivery' : 'Add ₹$need more for FREE delivery'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ]),
        if (!free && !s.isMember) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: const Color(0xFFE5E7EB), color: const Color(0xFFD4E684)),
          ),
        ],
      ]),
    );
  }

  Widget _deliveryCard(StoreController s) => _card(
        child: Row(children: [
          const Icon(Icons.location_on_outlined, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.pincode.isEmpty ? 'Add delivery PIN code' : 'Deliver to ${s.city.isEmpty ? '' : '${s.city} - '}${s.pincode}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${s.isMember ? 'Express delivery' : 'Estimated delivery'} by ${dateAfter(s.etaDays)}', style: const TextStyle(color: muted, fontSize: 11.5)),
            ]),
          ),
          TextButton(onPressed: () => showPinSheet(context), child: Text(s.pincode.isEmpty ? 'Add' : 'Change')),
        ]),
      );

  Widget _couponCard(StoreController s) {
    final available = s.coupons.where((c) => c.active && c.subtotalOk(s.subtotal)).toList();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.local_offer_outlined, size: 19),
          SizedBox(width: 8),
          Text('Coupons & offers', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        if (s.coupon != null && s.couponDiscount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFE6F6EC), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: success, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${s.coupon!.code} applied · you save ₹${s.couponDiscount}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
              GestureDetector(onTap: () => s.removeCoupon(), child: const Text('Remove', style: TextStyle(color: danger, fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          )
        else ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Enter coupon code', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(76, 46), backgroundColor: const Color(0xFF242424)),
              onPressed: () => _apply(s, code.text),
              child: const Text('Apply'),
            ),
          ]),
          if (available.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in available.take(4))
                GestureDetector(
                  onTap: () => _apply(s, c.code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: line, style: BorderStyle.solid)),
                    child: Text('${c.code} · ${c.label}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ],
        ],
        if (couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(couponMsg, style: const TextStyle(color: danger, fontSize: 12))),
      ]),
    );
  }

  Widget _summaryCard(StoreController s) => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Order summary', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 8),
          PriceRow(label: 'Subtotal (${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'})', value: '₹${s.subtotal}'),
          if (s.couponDiscount > 0) PriceRow(label: 'Coupon ${s.appliedCoupon ?? ''}', value: '-₹${s.couponDiscount}', color: success),
          PriceRow(label: 'Delivery', value: s.shipping == 0 ? 'FREE' : '₹${s.shipping}', color: s.shipping == 0 ? success : null),
          if (s.platformFeeAmount > 0) PriceRow(label: 'Platform fee', value: '₹${s.platformFeeAmount}'),
          if (s.gstAmount > 0) PriceRow(label: 'GST', value: '₹${s.gstAmount}'),
          const Divider(height: 20),
          PriceRow(label: 'Total', value: '₹${s.total}', bold: true),
          if (s.savings + s.couponDiscount > 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFE6F6EC), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.savings_outlined, size: 16, color: success),
                const SizedBox(width: 8),
                Text('You save ₹${s.savings + s.couponDiscount} on this order', style: const TextStyle(color: success, fontWeight: FontWeight.w800, fontSize: 12)),
              ]),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final lines = s.cartLines;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F6),
        title: const Text('Shopping cart'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(child: Text('${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'}', style: const TextStyle(color: muted, fontSize: 12.5, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: lines.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 88, height: 88, decoration: const BoxDecoration(color: Color(0xFFF4F4F6), shape: BoxShape.circle), child: const Icon(Icons.shopping_bag_outlined, size: 38, color: muted)),
                  const SizedBox(height: 16),
                  const Text('Your bag is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Explore the collection and add something you love.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12.5)),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF242424), minimumSize: const Size(170, 46), shape: const StadiumBorder()),
                    onPressed: () {
                      if (canPop) {
                        Navigator.of(context).pop();
                      } else {
                        shellTab.value = 0;
                      }
                    },
                    child: const Text('Start shopping'),
                  ),
                ]),
              ),
            )
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
                  _freeShipCard(s),
                  ...lines.map((l) => _line(s, l)),
                  _deliveryCard(s),
                  _couponCard(s),
                  _summaryCard(s),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, -4))],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      const Text('Total', style: TextStyle(color: muted, fontSize: 12)),
                      Text('₹${s.total}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(width: 20),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF242424), shape: const StadiumBorder()),
                          onPressed: () async {
                            if (!await ensureLogin(context)) return;
                            if (!context.mounted) return;
                            s.endBuyNow();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                          },
                          child: const Text('Checkout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ------------------------------------------------------------------ CHECKOUT
class CheckoutScreen extends StatefulWidget {
  final bool buyNow; // true = sirf ek product (Buy now)
  const CheckoutScreen({super.key, this.buyNow = false});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, email, mobile, addr, pin, town;
  bool initialized = false;
  bool busy = false;
  String? _checkoutRequestId;
  String payment = 'Cash on Delivery';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final s = StoreScope.read(context);
      name = TextEditingController(text: s.customerName);
      email = TextEditingController(text: s.customerEmail);
      mobile = TextEditingController(text: s.phone);
      addr = TextEditingController(text: s.address);
      pin = TextEditingController(text: s.pincode);
      town = TextEditingController(text: s.city);
      initialized = true;
    }
  }

  @override
  void dispose() {
    for (final c in [name, email, mobile, addr, pin, town]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _checkoutProgress() {
    Widget step(String label, int number, {bool done = false, bool active = false}) => Expanded(child: Column(children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(
        color: done ? const Color(0xFFD4E684) : (active ? const Color(0xFF242424) : Colors.white),
        shape: BoxShape.circle, border: Border.all(color: done || active ? const Color(0xFFD4E684) : const Color(0xFFE4E4E0))),
        child: Center(child: done ? const Icon(Icons.check, size: 16, color: Color(0xFF242424)) : Text('$number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : const Color(0xFF777777)))),
      ),
      const SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 10.5, fontWeight: active || done ? FontWeight.w800 : FontWeight.w500, color: const Color(0xFF242424))),
    ]));
    return Container(margin: const EdgeInsets.only(bottom: 18), padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAEAE6))),
      child: Row(children: [step('Account', 1, done: true), const Icon(Icons.chevron_right, size: 17, color: Color(0xFFD4E684)), step('Delivery', 2, done: true), const Icon(Icons.chevron_right, size: 17, color: Color(0xFFD4E684)), step('Payment', 3, active: true), const Icon(Icons.chevron_right, size: 17, color: Colors.black26), step('Review', 4)]),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? type, bool required = true, String? Function(String?)? validator, void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        onChanged: onChanged,
        validator: validator ?? (v) => required && (v == null || v.trim().isEmpty) ? 'This field is required' : null,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 19)),
      ),
    );
  }

  Widget _paymentOption(String value, String subtitle, IconData icon) {
    final selected = payment == value;
    return InkWell(onTap: () => setState(() => payment = value), borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(duration: const Duration(milliseconds: 160), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: selected ? const Color(0xFFF8F8F6) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? const Color(0xFF242424) : const Color(0xFFE6E6E2), width: selected ? 1.5 : 1)),
        child: Row(children: [Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFF0F1EB), shape: BoxShape.circle), child: Icon(icon, size: 19, color: const Color(0xFF242424))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Color(0xFF777777), fontSize: 11.5))])), Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF242424) : Colors.black38, size: 21)]),
      ),
    );
  }

  Future<void> _onPinChanged(String v) async {
    if (v.length == 6) {
      final s = StoreScope.read(context);
      final t = await s.lookupPin(v);
      if (t != null && mounted) setState(() => town.text = t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout'), backgroundColor: const Color(0xFFF8F8F6)),
      body: Form(
        key: form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _checkoutProgress(),
          if (widget.buyNow) ...[
            const Text('Buying', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...s.activeLines.map((l) {
              final p = s.productById(l.pid)!;
              final extra = [if (l.size.isNotEmpty) 'Size ${l.size}', if (l.color.isNotEmpty) l.color].join(' · ');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                child: Row(children: [
                  ProductThumb(product: p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (extra.isNotEmpty) Text(extra, style: const TextStyle(color: muted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('₹${s.unitPrice(l)}  ·  Qty 1${l.subDays > 0 ? '  ·  Every ${l.subDays} days' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                    ]),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
          ],
          const Text('Delivery details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _field(name, 'Full name', Icons.person_outline),
          _field(mobile, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone, validator: (v) => phoneCheck((v ?? '').trim())),
          _field(email, 'Email address (optional)', Icons.email_outlined, type: TextInputType.emailAddress, required: false),
          _field(addr, 'House / street / area', Icons.location_on_outlined),
          Row(children: [
            Expanded(child: _field(pin, 'PIN code', Icons.pin_drop_outlined, type: TextInputType.number, validator: (v) => pinCheck((v ?? '').trim()), onChanged: _onPinChanged)),
            const SizedBox(width: 10),
            Expanded(child: _field(town, 'City', Icons.location_city_outlined)),
          ]),
          Container(
            padding: const EdgeInsets.all(13),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: line)),
            child: Row(children: [
              Icon(s.isMember ? Icons.bolt_rounded : Icons.local_shipping_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('${s.isMember ? 'Express delivery' : 'Estimated delivery'} by ${dateAfter(s.etaDays)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Payment method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _paymentOption('Cash on Delivery', 'Pay when you receive your order', Icons.account_balance_wallet_outlined),
          const SizedBox(height: 10),
          _paymentOption('Online payment', 'UPI, credit/debit cards, netbanking and wallets', Icons.credit_card_outlined),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
            child: Column(children: [
              PriceRow(label: 'Items total', value: '₹${s.subtotal}'),
              if (s.couponDiscount > 0) PriceRow(label: 'Coupon ${s.appliedCoupon ?? ''}', value: '-₹${s.couponDiscount}', color: success),
              PriceRow(label: 'Delivery', value: s.shipping == 0 ? 'FREE' : '₹${s.shipping}', color: s.shipping == 0 ? success : null),
              const Divider(),
              PriceRow(label: 'Payable amount', value: '₹${s.total}', bold: true),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final issue = s.stockIssue();
                    if (issue != null) {
                      toast(context, issue);
                      return;
                    }
                    final online = payment == 'Online payment';
                    final paidTotal = s.total;
                    final paymentLabel = online ? 'Online payment' : 'Cash on Delivery';
                    setState(() => busy = true);
                    await s.saveProfile(name: name.text.trim(), email: email.text.trim(), mobile: mobile.text.trim(), addr: addr.text.trim(), pin: pin.text.trim(), town: town.text.trim());
                    if (!AppConfig.supabaseReady || !s.isLoggedIn) {
                      setState(() => busy = false);
                      toast(context, 'Secure checkout is not configured. Please contact support.');
                      return;
                    }
                    final create = await Cloud.invokeFunction('razorpay-checkout', {
                      'action': 'create_order',
                      'checkout_id': _checkoutRequestId ??= DateTime.now().microsecondsSinceEpoch.toString(),
                      'payment_method': online ? 'razorpay' : 'cod',
                      'items': s.activeLines.map((l) => {'pid': l.pid, 'qty': l.qty, 'size': l.size, 'color': l.color, if (l.subDays > 0 && s.settings.subEnabled) 'sub_days': l.subDays}).toList(),
                      'coupon_code': s.appliedCoupon ?? '',
                      'name': name.text.trim(),
                      'phone': mobile.text.trim(),
                      'address': '${addr.text.trim()}, ${town.text.trim()} - ${pin.text.trim()}',
                    });
                    if (!mounted) return;
                    if (!create.ok || create.data == null) {
                      setState(() => busy = false);
                      toast(context, create.error ?? 'Could not create order');
                      return;
                    }
                    final serverOrder = create.data!;
                    final orderId = '${serverOrder['order_id'] ?? ''}';
                    if (online && serverOrder['already_paid'] != true) {
                      final amountPaise = (serverOrder['amount'] as num?)?.toInt() ?? 0;
                      final pr = await payWithRazorpay(
                        amountRupees: (amountPaise / 100).round(),
                        description: 'Order at ${s.settings.appName}',
                        razorpayOrderId: '${serverOrder['razorpay_order_id'] ?? ''}',
                        razorpayKeyId: '${serverOrder['key_id'] ?? ''}',
                        name: name.text.trim(),
                        email: email.text.trim().isEmpty ? s.authEmail : email.text.trim(),
                        phone: mobile.text.trim(),
                      );
                      if (!mounted) return;
                      if (!pr.ok) {
                        setState(() => busy = false);
                        toast(context, '${pr.message}. Your order will remain payment-pending until the gateway confirms its final status.');
                        return;
                      }
                      final verify = await Cloud.invokeFunction('razorpay-checkout', {
                        'action': 'verify_payment',
                        'order_id': orderId,
                        'razorpay_order_id': '${serverOrder['razorpay_order_id'] ?? ''}',
                        'razorpay_payment_id': pr.paymentId,
                        'razorpay_signature': pr.signature,
                      });
                      if (!mounted) return;
                      if (!verify.ok || verify.data?['verified'] != true) {
                        setState(() => busy = false);
                        toast(context, 'Payment verification is pending. Please do not pay again; contact support with Order $orderId.');
                        return;
                      }
                    }
                    await s.syncCloud();
                    _checkoutRequestId = null;
                    if (!mounted) return;
                    setState(() => busy = false);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId, payment: paymentLabel, total: paidTotal)));
                  },
            child: Text(busy ? 'Placing order...' : 'Place order · ₹${s.total}'),
          ),
        ]),
      ),
    );
  }
}

class OrderSuccessScreen extends StatelessWidget {
  final String orderId, payment;
  final int total;
  const OrderSuccessScreen({super.key, required this.orderId, this.payment = '', this.total = 0});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final o = s.orderById(orderId);
    final pay = (o != null && '${o['payment'] ?? ''}'.isNotEmpty) ? '${o['payment']}' : payment;
    final tot = (o != null && o['total'] != null) ? '${o['total']}' : '$total';
    final when = shortDate((o != null && o['date'] != null) ? '${o['date']}' : DateTime.now().toIso8601String());

    void home(int tab) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      shellTab.value = tab;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) home(0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE9EAEC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 30, offset: Offset(0, 10))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 22),
                  const Icon(Icons.verified_rounded, color: kSuccessGreen, size: 68),
                  const SizedBox(height: 14),
                  const Text('Your order has been\nsuccessfully submitted',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.25)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: kReceiptGrey, borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      ReceiptRow('Order ID', orderId),
                      const Divider(height: 10),
                      ReceiptRow('Payment Method', pay.isEmpty ? '-' : pay),
                      const Divider(height: 10),
                      ReceiptRow('Date & Time', when),
                      const Divider(height: 10),
                      ReceiptRow('Total', '₹$tot', bold: true),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  BlackButton(label: 'Go to my account', height: 48, radius: 16, onTap: () => home(3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          final nav = Navigator.of(context);
                          nav.popUntil((r) => r.isFirst);
                          nav.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
                        },
                        child: const Text('Track order', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => home(0),
                        child: const Text('Continue shopping', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
