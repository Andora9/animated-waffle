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
  String? _checkoutRequestId;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final lines = s.cartLines;
    final st = s.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bag'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(child: Text('${s.itemCount} ${s.itemCount == 1 ? 'item' : 'items'}', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: lines.isEmpty
          ? const EmptyState(title: 'Your cart is empty', subtitle: 'Explore the collection and add something you love.')
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  ...List.generate(lines.length, (i) {
                    final l = lines[i];
                    final p = s.productById(l.pid)!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        ProductThumb(product: p),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.brand, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w900)),
                            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (l.size.isNotEmpty || l.color.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text([if (l.size.isNotEmpty) 'Size ${l.size}', if (l.color.isNotEmpty) l.color].join(' · '),
                                    style: const TextStyle(color: muted, fontSize: 11)),
                              ),
                            const SizedBox(height: 5),
                            Text('₹${p.price}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 7),
                            Row(children: [
                              QtyButton(icon: Icons.remove, onTap: () => s.setQty(l, l.qty - 1)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w900))),
                              QtyButton(
                                icon: Icons.add,
                                onTap: () {
                                  if (l.qty >= p.stock) {
                                    toast(context, 'Only ${p.stock} available');
                                  } else {
                                    s.setQty(l, l.qty + 1);
                                  }
                                },
                              ),
                            ]),
                          ]),
                        ),
                        IconButton(onPressed: () => s.setQty(l, 0), icon: const Icon(Icons.delete_outline)),
                      ]),
                    );
                  }),

                  // coupon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: softBox(2, radius: 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Coupon', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (s.coupon != null && s.couponDiscount > 0)
                        Row(children: [
                          const Icon(Icons.check_circle, color: success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${s.coupon!.code} applied  (-₹${s.couponDiscount})', style: const TextStyle(fontWeight: FontWeight.w800))),
                          TextButton(onPressed: () => s.removeCoupon(), child: const Text('Remove')),
                        ])
                      else
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
                            style: FilledButton.styleFrom(minimumSize: const Size(80, 46)),
                            onPressed: () async {
                              final r = await s.applyCoupon(code.text);
                              setState(() => couponMsg = r ?? '');
                              if (r == null) code.clear();
                            },
                            child: const Text('Apply'),
                          ),
                        ]),
                      if (couponMsg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(couponMsg, style: const TextStyle(color: danger, fontSize: 12))),
                    ]),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: line)),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    PriceRow(label: 'Subtotal', value: '₹${s.subtotal}'),
                    if (s.couponDiscount > 0) PriceRow(label: 'Coupon', value: '-₹${s.couponDiscount}', color: success),
                    PriceRow(label: 'Delivery', value: s.shipping == 0 ? 'FREE' : '₹${s.shipping}', color: s.shipping == 0 ? success : null),
                    if (s.shipping > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Add ₹${st.freeShipAbove - s.subtotal} more for free delivery', style: const TextStyle(color: muted, fontSize: 11)),
                      ),
                    const Divider(height: 18),
                    PriceRow(label: 'Total', value: '₹${s.total}', bold: true),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (!await ensureLogin(context)) return;
                          if (!context.mounted) return;
                          s.endBuyNow();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                        },
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 50), backgroundColor: Colors.black, shape: const StadiumBorder()),
                        child: const Text('Checkout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: form,
        child: ListView(padding: const EdgeInsets.all(18), children: [
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
                      Text('₹${p.price}  ·  Qty 1', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
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
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'Cash on Delivery',
            groupValue: payment,
            onChanged: (v) => setState(() => payment = v!),
            title: const Text('Cash on Delivery'),
            subtitle: const Text('Pay when your order arrives'),
          ),
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'Online payment',
            groupValue: payment,
            onChanged: (v) => setState(() => payment = v!),
            title: const Text('Pay online'),
            subtitle: const Text('UPI, cards, netbanking, wallets (Razorpay)'),
          ),
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
                      'items': s.activeLines.map((l) => {'pid': l.pid, 'qty': l.qty, 'size': l.size, 'color': l.color}).toList(),
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
