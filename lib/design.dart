// =====================================================================
//  DESIGN KIT  -  PDF wale UI components (banner, tracking, plan card, receipt)
//  Colors / sizes yahin se badlo, poori app me ek saath reflect hoga.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets.dart';

const Color kBrandGreen = Color(0xFFA4D65E);
const Color kInfoBg = Color(0xFFE8F0FE);
const Color kInfoFg = Color(0xFF1967D2);
const Color kCardGrey = Color(0xFFF5F7FA);
const Color kThumbGrey = Color(0xFFF2F4F7);
const Color kReceiptGrey = Color(0xFFF8F9FA);
const Color kSuccessGreen = Color(0xFF4CD964);
const Color kBlack = Color(0xFF000000);

/// Kahin se bhi `shellTab.value = 3` karo to bottom tab Account par chala jata hai.
final ValueNotifier<int> shellTab = ValueNotifier<int>(-1);

// ---------------------------------------------------------------- PAGE 2: PROMO BANNER
class _Dots extends StatelessWidget {
  final int count, active;
  const _Dots({required this.count, required this.active});
  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: i == active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == active ? Colors.black : Colors.black26,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class PromoBannerCard extends StatelessWidget {
  final String tag, title, button, image;
  final int count, active;
  final double height;
  final VoidCallback? onTap;
  const PromoBannerCard({
    super.key,
    this.tag = '',
    this.title = '',
    this.button = 'Shop Now',
    this.image = '',
    this.count = 1,
    this.active = 0,
    this.height = 176,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image.trim().isNotEmpty;
    final legacy = tag.isEmpty && title.isEmpty && hasImage;

    // Purane (sirf image wale) banners waise hi full-width dikhte hain.
    if (legacy) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              NetImage(url: image, fit: BoxFit.cover, fallback: const ColoredBox(color: kBrandGreen)),
              Positioned(bottom: 10, left: 0, right: 0, child: _Dots(count: count, active: active)),
            ]),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB9E277), kBrandGreen, Color(0xFF93C94A)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(children: [
          if (hasImage)
            Positioned(
              right: 8,
              top: 10,
              bottom: 0,
              width: 150,
              child: NetImage(url: image, fit: BoxFit.contain, fallback: const SizedBox.shrink()),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 18, hasImage ? 150 : 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tag.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                    child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                if (tag.isNotEmpty) const SizedBox(height: 10),
                if (title.isNotEmpty)
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black, height: 1.2),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 4, top: 4, bottom: 4),
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(button.isEmpty ? 'Shop Now' : button,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 12),
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFE2E8F0),
                      child: Icon(Icons.north_east, color: Colors.black, size: 16),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(bottom: 10, left: 0, right: 0, child: _Dots(count: count, active: active)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- PAGE 1: TRACKING
/// Order status -> 3 stage stepper: 0 Received, 1 In Transit, 2 Delivered
int trackingStage(String status) {
  switch (status) {
    case 'Shipped':
    case 'Out for delivery':
      return 1;
    case 'Delivered':
      return 2;
    default:
      return 0;
  }
}

class TrackingHeaderCard extends StatelessWidget {
  final String orderId, status;
  const TrackingHeaderCard({super.key, required this.orderId, required this.status});

  @override
  Widget build(BuildContext context) {
    final cancelled = status == 'Cancelled';
    final delivered = status == 'Delivered';
    final bg = cancelled ? const Color(0xFFFDECEC) : (delivered ? const Color(0xFFE6F6EC) : kInfoBg);
    final fg = cancelled ? const Color(0xFFDC2626) : (delivered ? const Color(0xFF059669) : kInfoFg);
    return Row(children: [
      CircleAvatar(
        backgroundColor: Colors.grey.shade100,
        child: const Icon(Icons.inventory_2_outlined, color: Colors.black),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tracking ID:', style: TextStyle(color: Colors.grey, fontSize: 12)),
          Row(children: [
            Flexible(
              child: Text('#$orderId',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: orderId));
                if (context.mounted) toast(context, 'Order ID copied');
              },
              child: const Icon(Icons.copy_rounded, size: 15, color: Colors.grey),
            ),
          ]),
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ]);
  }
}

class ShipmentStepper extends StatelessWidget {
  final String status;
  final List<String> times; // 3 items (Received, In Transit, Delivered)
  const ShipmentStepper({super.key, required this.status, this.times = const ['', '', '']});

  Widget _node(String title, String time, int i, int stage, bool cancelled, CrossAxisAlignment align) {
    final done = i <= stage;
    final bad = cancelled && i == 0;
    final color = bad ? const Color(0xFFDC2626) : (done ? Colors.black : Colors.grey.shade300);
    return SizedBox(
      width: 74,
      child: Column(crossAxisAlignment: align, children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: color,
          child: Icon(bad ? Icons.close : (done ? Icons.check : Icons.circle), size: 13, color: Colors.white),
        ),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    );
  }

  Widget _line(bool on) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(height: 2, color: on ? Colors.black : Colors.grey.shade300),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cancelled = status == 'Cancelled';
    final stage = cancelled ? 0 : trackingStage(status);
    final t = [...times, '', '', ''];
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _node('Received', t[0], 0, stage, cancelled, CrossAxisAlignment.start),
      _line(!cancelled && stage >= 1),
      _node('In Transit', t[1], 1, stage, cancelled, CrossAxisAlignment.center),
      _line(!cancelled && stage >= 2),
      _node('Delivered', t[2], 2, stage, cancelled, CrossAxisAlignment.end),
    ]);
  }
}

class BlackButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double radius, height;
  const BlackButton({super.key, required this.label, this.icon, this.onTap, this.radius = 14, this.height = 52});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: icon == null ? const SizedBox.shrink() : Icon(icon, color: Colors.white, size: 20),
          label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
        ),
      );
}

class DetailRow extends StatelessWidget {
  final String label, value;
  final bool warning;
  const DetailRow(this.label, this.value, {super.key, this.warning = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (warning) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
              if (warning) const SizedBox(width: 4),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: warning ? Colors.red : Colors.black)),
              ),
            ]),
          ),
        ]),
      );
}

class ShipmentDetailsCard extends StatelessWidget {
  final List<DetailRow> rows;
  const ShipmentDetailsCard({super.key, required this.rows});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kCardGrey, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.local_shipping_outlined, size: 18, color: Colors.grey),
            SizedBox(width: 8),
            Text('Delivery Details', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ...rows,
        ]),
      );
}

// ---------------------------------------------------------------- PAGE 5 / 7: PLAN CARD
class PlanCard extends StatelessWidget {
  final String title, price, period, cta;
  final List<String> features;
  final bool highlighted, enabled;
  final VoidCallback? onTap;
  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    this.cta = 'Upgrade',
    this.highlighted = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: highlighted ? null : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Stack(children: [
        if (highlighted) ...[
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 200,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x66FF8A65), Color(0x00FF8A65)]),
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -50,
            child: Container(
              width: 170,
              height: 130,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0x5586E3C0), Color(0x0086E3C0)]),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            Text(price, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
            Text(period, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: enabled ? onTap : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: highlighted ? const Color(0xFF1E1E1E) : const Color(0xFFE2E8F0),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(cta,
                    style: TextStyle(
                        color: enabled && highlighted ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 18),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check, size: 16, color: Colors.black87),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: const TextStyle(fontSize: 12.5, color: Colors.black87))),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- PAGE 6: ORDER SUCCESS
class ReceiptRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const ReceiptRow(this.label, this.value, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: 13, color: Colors.black)),
          ),
        ]),
      );
}
