import 'package:flutter/material.dart';
import 'cloud.dart';
import 'design.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Customer ke liye membership plans (admin ke "Membership plans" se control hote hain).
/// Plan active + price admin panel se set hota hai. Upgrade button abhi WhatsApp/support
/// par request bhejta hai; owner admin panel se membership activate karta hai.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  late Future<List<Map<String, dynamic>>?> _plans;

  @override
  void initState() {
    super.initState();
    _plans = Cloud.select('membership_plans', query: {'select': '*', 'active': 'eq.true', 'order': 'price_paise.asc'});
  }

  Future<void> _join(String plan) async {
    final st = StoreScope.read(context).settings;
    var n = (st.whatsapp.isEmpty ? st.supportPhone : st.whatsapp).replaceAll(RegExp(r'\D'), '');
    if (n.isEmpty) {
      toast(context, 'Support number is not available right now');
      return;
    }
    if (n.length == 10) n = '91$n';
    await openUrl('https://wa.me/$n?text=${Uri.encodeComponent('Hi, I want to join the $plan membership')}');
  }

  String _period(int days) {
    if (days == 30) return 'per month';
    if (days == 365) return 'per year';
    return 'for $days days';
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: FutureBuilder<List<Map<String, dynamic>>?>(
        future: _plans,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final plans = snap.data ?? const <Map<String, dynamic>>[];
          if (plans.isEmpty) {
            return const EmptyState(
              title: 'No plans available',
              subtitle: 'Membership plans will appear here soon.',
              icon: Icons.workspace_premium_outlined,
            );
          }
          final goldIdx = plans.indexWhere((p) => '${p['id']}' == 'gold');
          final hi = goldIdx >= 0 ? goldIdx : 0;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (s.isMember)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFE6F6EC), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.verified_rounded, color: success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Your membership is active · ${s.memberDaysLeft} days left',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ]),
              ),
            ...List.generate(plans.length, (i) {
              final p = plans[i];
              final paise = (p['price_paise'] as num?)?.toInt() ?? 0;
              final days = (p['duration_days'] as num?)?.toInt() ?? 30;
              final raw = (p['benefits'] as List?)?.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList() ?? <String>[];
              final features = raw.isNotEmpty
                  ? raw
                  : <String>[
                      'Free delivery on every order',
                      'Faster delivery in ${s.settings.etaDaysMember} days',
                      'Member-only offers',
                    ];
              final title = '${p['title'] ?? 'Plan'}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PlanCard(
                  title: title,
                  price: '₹${(paise / 100).round()}',
                  period: _period(days),
                  features: features,
                  highlighted: i == hi,
                  enabled: !s.isMember,
                  cta: s.isMember ? 'Active' : 'Upgrade',
                  onTap: () => _join(title),
                ),
              );
            }),
          ]);
        },
      ),
    );
  }
}
