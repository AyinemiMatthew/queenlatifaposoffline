import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

class SubscriptionUsageLimitsScreen extends StatefulWidget {
  const SubscriptionUsageLimitsScreen({super.key});

  @override
  State<SubscriptionUsageLimitsScreen> createState() =>
      _SubscriptionUsageLimitsScreenState();
}

class _SubscriptionUsageLimitsScreenState
    extends State<SubscriptionUsageLimitsScreen>
    with SingleTickerProviderStateMixin {
  static const List<Map<String, String>> _plans = [
    {'id': 'free_trial', 'name': 'Free Trial'},
    {'id': 'starter', 'name': 'Starter'},
    {'id': 'professional', 'name': 'Professional'},
    {'id': 'enterprise', 'name': 'Enterprise'},
  ];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _readControllers = {};
  final Map<String, TextEditingController> _writeControllers = {};
  late final TabController _tabController;
  bool _loading = true;
  String? _savingPlan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _plans.length, vsync: this);
    for (final plan in _plans) {
      final id = plan['id']!;
      _readControllers[id] = TextEditingController();
      _writeControllers[id] = TextEditingController();
    }
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    try {
      await Future.wait(
        _plans.map((plan) async {
          final id = plan['id']!;
          final doc = await _db
              .collection('subscription_usage_limits')
              .doc(id)
              .get();
          final data = doc.data();
          if (data == null) return;
          _readControllers[id]!.text = data['monthlyReads']?.toString() ?? '';
          _writeControllers[id]!.text = data['monthlyWrites']?.toString() ?? '';
        }),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load plan limits: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLimits(String planId, String planName) async {
    final readsText = _readControllers[planId]!.text.trim();
    final writesText = _writeControllers[planId]!.text.trim();
    final reads = readsText.isEmpty ? null : int.tryParse(readsText);
    final writes = writesText.isEmpty ? null : int.tryParse(writesText);

    if ((readsText.isNotEmpty && reads == null) ||
        (writesText.isNotEmpty && writes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter whole-number limits.')),
      );
      return;
    }

    setState(() => _savingPlan = planId);
    try {
      await _db.collection('subscription_usage_limits').doc(planId).set({
        'plan': planId,
        'monthlyReads': reads,
        'monthlyWrites': writes,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': context.read<Datafeed>().staffemail,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$planName limits saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save plan limits: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPlan = null);
    }
  }

  Widget _buildPlanForm(Map<String, String> plan) {
    final id = plan['id']!;
    final name = plan['name']!;
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth > 760
            ? (constraints.maxWidth - 20) / 2
            : constraints.maxWidth;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '$name monthly usage limits',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: _limitField(
                    controller: _readControllers[id]!,
                    label: 'Maximum document reads',
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: _limitField(
                    controller: _writeControllers[id]!,
                    label: 'Maximum document writes',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF415A77),
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: _savingPlan == null
                    ? () => _saveLimits(id, name)
                    : null,
                icon: _savingPlan == id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text('Save $name limits'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _limitField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        floatingLabelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        helperText: 'Leave blank for no configured limit',
        helperStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Usage Limits'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: colorScheme.onSurface,
          indicatorColor: colorScheme.primary,
          tabs: _plans.map((plan) => Tab(text: plan['name'])).toList(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth < 760
              ? constraints.maxWidth
              : 760.0;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: contentWidth,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: _plans.map(_buildPlanForm).toList(),
                    ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _readControllers.values) {
      controller.dispose();
    }
    for (final controller in _writeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
