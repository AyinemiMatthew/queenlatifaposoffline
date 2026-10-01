import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/Datafeed.dart';

class StaffProfile extends StatefulWidget {
  const StaffProfile({Key? key}) : super(key: key);

  @override
  State<StaffProfile> createState() => _StaffProfileState();
}

class _StaffProfileState extends State<StaffProfile> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<Datafeed>().getdata();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        final staff = datafeed.currentStaff;
        final company = datafeed.currentCompany;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('My Profile'),
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: colorScheme.surface,
                            child: Text(
                              datafeed.staff.isNotEmpty
                                  ? datafeed.staff[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            datafeed.staff.isNotEmpty ? datafeed.staff : 'User',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              staff?.accesslevel ?? 'Staff',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personal Information Card
                    _buildSectionCard(
                      title: 'Personal Information',
                      icon: Icons.person,
                      children: [
                        _buildInfoRow(
                          icon: Icons.badge,
                          label: 'Staff ID',
                          value: staff?.id ?? 'N/A',
                        ),
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Full Name',
                          value: staff?.name ?? datafeed.staff,
                        ),
                        _buildInfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: staff?.email ?? 'N/A',
                        ),
                        _buildInfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: staff?.phone ?? 'N/A',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Company Information Card
                    _buildSectionCard(
                      title: 'Company Information',
                      icon: Icons.business,
                      children: [
                        _buildInfoRow(
                          icon: Icons.business_center,
                          label: 'Company',
                          value: company?.name ?? datafeed.company,
                        ),
                        _buildInfoRow(
                          icon: Icons.tag,
                          label: 'Company ID',
                          value: staff?.companyid ?? datafeed.companyid,
                        ),
                        _buildInfoRow(
                          icon: Icons.category,
                          label: 'Company Type',
                          value: datafeed.companytype,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Access Information Card
                    if (staff?.pricingmode.isNotEmpty ?? false)
                      _buildSectionCard(
                        title: 'Access & Permissions',
                        icon: Icons.security,
                        children: [
                          _buildInfoRow(
                            icon: Icons.admin_panel_settings,
                            label: 'Access Level',
                            value: staff?.accesslevel ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.price_check,
                                      size: 20,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Pricing Modes',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: (staff?.pricingmode ?? [])
                                      .map(
                                        (mode) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            mode,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.secondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Account Information Card
                    _buildSectionCard(
                      title: 'Account Information',
                      icon: Icons.info_outline,
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: 'Created At',
                          value: staff?.createdat != null
                              ? _formatDate(staff!.createdat)
                              : 'N/A',
                        ),
                        _buildInfoRow(
                          icon: Icons.person_add,
                          label: 'Created By',
                          value: staff?.createdby ?? 'N/A',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colorScheme.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
