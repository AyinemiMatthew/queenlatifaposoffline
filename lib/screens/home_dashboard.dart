import 'dart:math';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/dashboard_provider.dart';
import 'package:kologsoft/providers/theme_provider.dart';
import 'package:kologsoft/screens/salesTotal.dart';
import 'package:kologsoft/screens/sidebar.dart';
import 'package:kologsoft/widgets/offline_indicator.dart';
import 'package:provider/provider.dart';

import '../models/branch_stock_value.dart';
import '../models/sales_summary.dart';
import '../providers/routes.dart';
import 'companyreg.dart';
import 'debtpage.dart';
import 'expense_total.dart';
import '../paymentwidgets/showlogout.dart';

BoxDecoration _dashboardCardDecoration(ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
    boxShadow: [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

Color _dashboardDividerColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? const Color(0xFF415A77)
      : theme.colorScheme.outlineVariant;
}

class _DashboardLoadingPlaceholder extends StatefulWidget {
  final int rowCount;

  const _DashboardLoadingPlaceholder({this.rowCount = 5});

  @override
  State<_DashboardLoadingPlaceholder> createState() =>
      _DashboardLoadingPlaceholderState();
}

class _DashboardLoadingPlaceholderState
    extends State<_DashboardLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDarkMode
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : const Color(0xFFD1D5DB);
    final minimumOpacity = isDarkMode ? 0.35 : 0.55;
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: minimumOpacity + (_controller.value * (1 - minimumOpacity)),
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.rowCount, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: index.isEven ? 6 : 4,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 52,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

String _capitalizeFirstLowerRest(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) return normalized;

  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _selectedIndex = 0;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final datafeed = context.read<Datafeed>();
      print(datafeed.companytype);
      final dashb = context.read<DashboardProvider>();
      await datafeed.getdata();
      await datafeed.loadDashboardPeriod();
      dashb.listenToBranchStock();
      datafeed.listenToDashboardSales();
    });
  }

  Future<void> _editCompany(BuildContext context, Datafeed datafeed) async {
    final db = FirebaseFirestore.instance;
    final doc = await db.collection('companies').doc(datafeed.companyid).get();

    if (!doc.exists) return;
    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyRegPage(
          docId: doc.id,
          data: doc.data() as Map<String, dynamic>,
          isSuperAdmin: datafeed.accesslevel == 'super admin',
          isSystemAdmin: datafeed.accesslevel == 'systemadmin',
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext parentContext) {
    LogoutDialog.show(parentContext);
  }

  void _showChangePasswordDialog(BuildContext context, Datafeed datafeed) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.lock_reset,
                                  color: colorScheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Change Password',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Update your account password',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: currentPasswordController,
                            obscureText: !showCurrentPassword,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showCurrentPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                color: colorScheme.onSurfaceVariant,
                                onPressed: () {
                                  setState(() {
                                    showCurrentPassword = !showCurrentPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 1.4,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter current password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: newPasswordController,
                            obscureText: !showNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: Icon(
                                Icons.lock,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                color: colorScheme.onSurfaceVariant,
                                onPressed: () {
                                  setState(() {
                                    showNewPassword = !showNewPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 1.4,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              helperText: 'Must be at least 6 characters',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter new password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: !showConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm New Password',
                              prefixIcon: Icon(
                                Icons.lock,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                color: colorScheme.onSurfaceVariant,
                                onPressed: () {
                                  setState(() {
                                    showConfirmPassword = !showConfirmPassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: colorScheme.primary,
                                  width: 1.4,
                                ),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceVariant,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm password';
                              }
                              if (value != newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          setState(() => isLoading = true);
                                          try {
                                            await datafeed.changePassword(
                                              currentPasswordController.text,
                                              newPasswordController.text,
                                            );
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Password changed successfully',
                                                    style: TextStyle(
                                                      color: ColorScheme.of(
                                                        context,
                                                      ).onPrimary,
                                                    ),
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setState(() => isLoading = false);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error: $e',
                                                    style: TextStyle(
                                                      color: ColorScheme.of(
                                                        context,
                                                      ).onPrimary,
                                                    ),
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Update Password'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth <= 512;
    bool isSmallTablet = screenWidth < 774;
    bool isTablet = screenWidth < 900;
    bool isMediumTablet = screenWidth < 1087;
    bool isBigTablet = screenWidth < 1200;
    // print(screenWidth);

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final themeProvider = context.watch<ThemeProvider>();
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              '${(value.company.toString().toUpperCase())}-${value.dashboardPeriodLabel}',
            ),
            centerTitle: true,
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: themeProvider.isLightTheme
                    ? 'Switch to dark theme'
                    : 'Switch to white theme',
                icon: Icon(
                  themeProvider.isLightTheme
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: colorScheme.onSurface,
                ),
                onPressed: () async {
                  try {
                    await themeProvider.toggleTheme();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not save theme preference: $error',
                        ),
                      ),
                    );
                  }
                },
              ),
              // User menu
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 16,
                      child: Text(
                        value.staff.isNotEmpty
                            ? value.staff[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (screenWidth > 600)
                      Text(
                        value.staff.isNotEmpty ? value.staff : 'User',
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
                offset: const Offset(0, 50),
                color: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value.staff.isNotEmpty ? value.staff : 'User',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (value.companyemail.isNotEmpty)
                          Text(
                            value.companyemail,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Divider(
                          color: _dashboardDividerColor(context),
                          thickness: 1,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 20,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'My Profile',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  if (value.accesslevel == 'super admin' ||
                      value.accesslevel == 'systemadmin')
                    PopupMenuItem<String>(
                      value: 'company',
                      child: Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Edit Company',
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20, color: Colors.blue),
                        const SizedBox(width: 12),
                        Text(
                          'Change Password',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (String selectedValue) {
                  if (selectedValue == 'logout') {
                    _showLogoutDialog(context);
                  } else if (selectedValue == 'password') {
                    _showChangePasswordDialog(context, value);
                  } else if (selectedValue == 'profile') {
                    Navigator.pushNamed(context, Routes.staffprofile);
                  } else if (selectedValue == 'company') {
                    _editCompany(context, value);
                  }
                },
              ),
            ],
          ),
          drawer: Sidebar(),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OfflineIndicator(),
                  Wrap(
                    runSpacing: 15,
                    spacing: 15,
                    children: [
                      WorkPlaceWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.30
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.24
                            : screenWidth * 0.22,
                      ),
                      RespWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.17,
                      ),
                      MomoKpiWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.164,
                        //todayAmount: 0.00,
                        //yesterdayAmount: 0.00,
                      ),

                      TotalDebtWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.47
                            : isMediumTablet
                            ? screenWidth * 0.21
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.15
                            : screenWidth * 0.16,
                        //totalDebt: 0.00,
                      ),

                      BranchSales(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.98
                            : isMediumTablet
                            ? screenWidth * 0.98
                            : isBigTablet
                            ? screenWidth * 0.24
                            : screenWidth * 0.22,
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 108,
                    child: CarouselSlider(
                      options: CarouselOptions(
                        height: 108,
                        autoPlay: true,
                        autoPlayInterval: const Duration(seconds: 3),
                        autoPlayAnimationDuration: const Duration(
                          milliseconds: 800,
                        ),
                        enlargeCenterPage: false,
                        viewportFraction: isMobile
                            ? 0.47
                            : isSmallTablet
                            ? 0.30
                            : isTablet
                            ? 0.25
                            : 0.15,
                        enableInfiniteScroll: true,
                        scrollDirection: Axis.horizontal,
                      ),
                      items: [
                        _statCard(
                          context: context,
                          title: "SMS balance",
                          value: value.smsBalance.toString(),
                          subtitle: "Available",
                          icon: Icons.sms,
                          iconColor: Colors.blue,
                        ),
                        _statCard(
                          context: context,
                          title: "Total discount",
                          value: value.disCount.toStringAsFixed(2),
                          subtitle: "from sales",
                          icon: Icons.discount,
                          iconColor: Colors.deepOrange,
                        ),
                        _statCard(
                          context: context,
                          title: "Re-order",
                          value: value.companystockreorderbal.toString(),
                          subtitle: "Requires attention",
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                        ),
                        _statCard(
                          context: context,
                          title: "Expiring Soon",
                          value: "0",
                          subtitle: "Within 5 days",
                          icon: Icons.schedule,
                          iconColor: Colors.redAccent,
                        ),
                        _statCard(
                          context: context,
                          title: "Finished Stock",
                          value: value.companyfinishedstock.toString(),
                          subtitle: "Within 30 days",
                          icon: Icons.security_update_good_sharp,
                          iconColor: Colors.lightBlue,
                        ),
                        _statCard(
                          context: context,
                          title: "Available",
                          value: value.companyavailablestock.toString(),
                          subtitle: "Within 30 days",
                          icon: Icons.new_label_sharp,
                          iconColor: Colors.lightGreen,
                        ),
                        _statCard(
                          context: context,
                          title: "VAT",
                          value: "0",
                          subtitle: "Within 30 days",
                          icon: Icons.schedule,
                          iconColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 15),

                  Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      PieChartWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.98
                            : isBigTablet
                            ? screenWidth * 0.98
                            : screenWidth * 0.345,
                      ),
                      FeedbackWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.97
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.21,
                      ),
                      TopWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isTablet
                            ? screenWidth * 0.97
                            : isMediumTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.195,
                      ),

                      MonthlyRevenueWidget(
                        cwidth: isMobile
                            ? screenWidth * 0.95
                            : isSmallTablet
                            ? screenWidth * 0.97
                            : isTablet
                            ? screenWidth * 0.48
                            : isBigTablet
                            ? screenWidth * 0.48
                            : screenWidth * 0.195,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FeedbackWidget extends StatelessWidget {
  final double cwidth;
  const FeedbackWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Selector<DashboardProvider, List<BranchStockItem>>(
      selector: (_, provider) => provider.branchStockValue ?? [],
      builder: (context, branchStockValue, child) {
        return Container(
          height: 400,
          width: cwidth,
          decoration: _dashboardCardDecoration(colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch stock value',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: branchStockValue!.length + 1,
                    separatorBuilder: (_, __) => Divider(
                      color: _dashboardDividerColor(context),
                      thickness: 1,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      if (index == branchStockValue!.length) {
                        final total = branchStockValue!.fold(
                          0.0,
                          (sum, item) => sum + (item.stockValue ?? 0),
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate, color: Colors.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Grand Total",
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                "GHS ${NumberFormat('#,##0.00').format(total)}",

                                //total.toStringAsFixed(2),
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final feedback = branchStockValue?[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Container(
                            //   height: 30,
                            //   width: 30,
                            //   decoration: const BoxDecoration(
                            //     color: Color(0xFF3A6FF8),
                            //     shape: BoxShape.circle,
                            //   ),
                            //   child: const Icon(
                            //     Icons.house_outlined,
                            //     color: Colors.white,
                            //     size: 18,
                            //   ),
                            // ),
                            // const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _capitalizeFirstLowerRest(
                                        feedback!.branchName,
                                      ),
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "GHS ${NumberFormat('#,##0.00').format(feedback!.stockValue)}",
                                    //feedback!.stockValue.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      //fontSize: 14,
                                      //fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// dart
class PieChartWidget extends StatefulWidget {
  final double cwidth;

  const PieChartWidget({super.key, required this.cwidth});

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  Stream<WeeklySalesComparison>? _salesStream;
  String? _salesStreamKey;

  List<double> _normalizeWeek(List<num?>? week) {
    final w = week ?? <num?>[];

    return List<double>.generate(7, (i) {
      if (i >= w.length) return 0.0;

      final value = w[i];
      if (value == null) return 0.0;

      final d = value.toDouble();

      if (d.isNaN || d.isInfinite) {
        return 0.0;
      }

      return d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dashboardProvider = context.watch<DashboardProvider>();
    if (dashboardProvider.companyid.isEmpty) {
      return SizedBox(
        height: 420,
        width: widget.cwidth,
        child: _DashboardLoadingPlaceholder(rowCount: 7),
      );
    }

    final streamKey =
        '${dashboardProvider.companyid}|${dashboardProvider.branchid}|'
        '${dashboardProvider.accesslevel}';
    if (_salesStream == null || _salesStreamKey != streamKey) {
      _salesStream = dashboardProvider.weeklySalesComparisonStream();
      _salesStreamKey = streamKey;
    }

    return Container(
      height: 420,
      width: widget.cwidth,
      decoration: _dashboardCardDecoration(colorScheme),
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.hardEdge,
      child: StreamBuilder<WeeklySalesComparison>(
        stream: _salesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _DashboardLoadingPlaceholder(rowCount: 7);
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load weekly sales',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }

          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'No sales data found',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }

          final data = snapshot.data!;

          final current = _normalizeWeek(data.currentWeek);
          final previous = _normalizeWeek(data.previousWeek);

          final currentSpots = List.generate(
            7,
            (i) => FlSpot((i + 1).toDouble(), current[i]),
          );

          final previousSpots = List.generate(
            7,
            (i) => FlSpot((i + 1).toDouble(), previous[i]),
          );

          final allValues = [...current, ...previous];

          final rawMax = allValues.fold<double>(
            0,
            (max, e) => e > max ? e : max,
          );

          final rawMin = allValues.fold<double>(
            0,
            (min, e) => e < min ? e : min,
          );

          final maxY = rawMax > 0 ? rawMax * 1.15 : 10.0;
          final minY = rawMin < 0 ? rawMin * 1.15 : 0.0;

          final interval = (maxY - minY) / 5;

          final useCurve =
              rawMax > 0 &&
              rawMax / (allValues.where((e) => e > 0).length + 1) > 1.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Last week and current sales comparison',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      _LegendDot(color: Color(0xFF4FC3F7), text: 'Current'),
                      SizedBox(width: 12),
                      _LegendDot(color: Color(0xFFF5D76E), text: 'Previous'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ClipRect(
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: 7.4,
                      minY: minY,
                      maxY: maxY,

                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: true,
                        touchSpotThreshold: 24,
                        touchTooltipData: LineTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          tooltipBorderRadius: BorderRadius.circular(10),
                          getTooltipColor: (_) =>
                              colorScheme.surfaceContainerHighest,
                          getTooltipItems: (spots) {
                            const days = [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday',
                            ];
                            return spots.map((spot) {
                              final dayIndex = (spot.x.round() - 1).clamp(0, 6);
                              final isCurrent = spot.barIndex == 0;
                              final amount = isCurrent
                                  ? current[dayIndex]
                                  : previous[dayIndex];
                              final label = isCurrent ? 'Current' : 'Previous';
                              final lineColor = isCurrent
                                  ? const Color(0xFF4FC3F7)
                                  : const Color(0xFFF5D76E);
                              return LineTooltipItem(
                                '${days[dayIndex]} - $label\n'
                                'GHS ${amount.toStringAsFixed(2)}',
                                TextStyle(
                                  color: lineColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),

                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: colorScheme.onSurface.withValues(alpha: 0.38),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: colorScheme.onSurface.withValues(alpha: 0.16),
                          strokeWidth: 1,
                        ),
                      ),

                      borderData: FlBorderData(show: false),

                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              return SizedBox(
                                width: 42,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    NumberFormat('#,##0').format(value.round()),
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),

                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),

                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final style = TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              );

                              switch (value.toInt()) {
                                case 1:
                                  return Text("Mon", style: style);
                                case 2:
                                  return Text("Tue", style: style);
                                case 3:
                                  return Text("Wed", style: style);
                                case 4:
                                  return Text("Thu", style: style);
                                case 5:
                                  return Text("Fri", style: style);
                                case 6:
                                  return Text("Sat", style: style);
                                case 7:
                                  return Text("Sun", style: style);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                      ),

                      lineBarsData: [
                        LineChartBarData(
                          spots: currentSpots,
                          isCurved: useCurve,
                          color: const Color(0xFF4FC3F7),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: previousSpots,
                          isCurved: useCurve,
                          color: const Color(0xFFF5D76E),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MonthlyRevenueWidget extends StatefulWidget {
  final double cwidth;

  const MonthlyRevenueWidget({super.key, required this.cwidth});

  @override
  State<MonthlyRevenueWidget> createState() => _MonthlyRevenueWidgetState();
}

class _MonthlyRevenueWidgetState extends State<MonthlyRevenueWidget> {
  Stream<List<Map<String, dynamic>>>? _itemsStream;
  String? _itemsStreamKey;

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;
    if (_itemsStream == null ||
        _itemsStreamKey != datafeed.periodDashboardSummaryCacheKey) {
      _itemsStreamKey = datafeed.periodDashboardSummaryCacheKey;
      _itemsStream = datafeed.dashboardTopItemsStream('sales_value');
    }
    return Container(
      height: 400,
      width: widget.cwidth,
      decoration: _dashboardCardDecoration(colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Best 10 financial items',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Name',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Amount',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(color: _dashboardDividerColor(context), thickness: 1),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _itemsStream,
                initialData: datafeed.cachedDashboardTopItems('sales_value'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _DashboardLoadingPlaceholder();
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    key: const PageStorageKey('top10_items'),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: _dashboardDividerColor(context),
                      thickness: 1,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Padding(
                        key: ValueKey(item['itemid']),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (item['item'] ?? '').toString().isNotEmpty
                                    ? '${(item['item'] ?? '').toString()[0].toUpperCase()}${(item['item'] ?? '').toString().substring(1).toLowerCase()}'
                                    : '',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              " GHS ${NumberFormat('#,##0.00').format(item['sales_value'])}",
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopWidget extends StatefulWidget {
  final double cwidth;

  const TopWidget({super.key, required this.cwidth});

  @override
  State<TopWidget> createState() => _TopWidgetState();
}

class _TopWidgetState extends State<TopWidget> {
  Stream<List<Map<String, dynamic>>>? _itemsStream;
  String? _itemsStreamKey;

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;
    if (_itemsStream == null ||
        _itemsStreamKey != datafeed.periodDashboardSummaryCacheKey) {
      _itemsStreamKey = datafeed.periodDashboardSummaryCacheKey;
      _itemsStream = datafeed.dashboardTopItemsStream('sales_qty');
    }
    return Container(
      height: 400,
      width: widget.cwidth,
      decoration: _dashboardCardDecoration(colorScheme),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Best 10 qty items',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Name',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Qty',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(color: _dashboardDividerColor(context), thickness: 1),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _itemsStream,
                initialData: datafeed.cachedDashboardTopItems('sales_qty'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const _DashboardLoadingPlaceholder();
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No data',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: _dashboardDividerColor(context),
                      thickness: 1,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (item['item'] ?? '').toString().isNotEmpty
                                    ? '${(item['item'] ?? '').toString()[0].toUpperCase()}${(item['item'] ?? '').toString().substring(1).toLowerCase()}'
                                    : '',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              " ${NumberFormat('#,##0').format(item['sales_qty'])}",
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BranchSales extends StatefulWidget {
  final double cwidth;

  const BranchSales({super.key, required this.cwidth});

  @override
  State<BranchSales> createState() => _BranchSalesState();
}

class _BranchSalesState extends State<BranchSales> {
  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<DashboardProvider>(
      builder: (context, value, child) {
        return Container(
          height: 235,
          width: widget.cwidth,
          decoration: _dashboardCardDecoration(colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Branch Sales — Today',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: StreamBuilder<SalesSummary>(
                    stream: datafeed.StodayTotalsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const _DashboardLoadingPlaceholder();
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return Center(
                          child: Text(
                            'No sales data',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }

                      final entries = snapshot.data!.branchTotals.entries
                          .toList();

                      final grandTotal = entries.fold<double>(
                        0,
                        (sum, e) => sum + e.value,
                      );

                      return ListView.separated(
                        itemCount: entries.length + 1,
                        separatorBuilder: (_, __) => Divider(
                          color: _dashboardDividerColor(context),
                          thickness: 1,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          if (index == entries.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calculate,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Grand Total",
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "GHS ${NumberFormat('#,##0.00').format(grandTotal)}",
                                    // grandTotal.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final entry = entries[index];

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3A6FF8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.house_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _capitalizeFirstLowerRest(entry.key),
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        entry.value.toStringAsFixed(2),
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CsatWidget extends StatelessWidget {
  final double cwidth;
  const CsatWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: cwidth,
      height: 235,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Row(
            children: [
              Text(
                "CSAT",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Progress indicator (simplified version)
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // Filled portion (84%)
                FractionallySizedBox(
                  widthFactor: 0.84,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Percentage
          Text(
            '84%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),

          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                '100%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiddleWidget extends StatelessWidget {
  final double cwidth;
  const MiddleWidget({super.key, required this.cwidth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16),
      height: 235,
      width: cwidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "950",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: "GHS\n",
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 20),
                ),
                TextSpan(
                  text: "MOMO today",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

class MomoKpiWidget extends StatefulWidget {
  final double cwidth;

  const MomoKpiWidget({super.key, required this.cwidth});

  @override
  State<MomoKpiWidget> createState() => _MomoKpiWidgetState();
}

class _MomoKpiWidgetState extends State<MomoKpiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _amountAnim;

  double _currentAmount = 0.0;
  double _previousAmount = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _amountAnim = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  void _animateTo(double newValue) {
    if (!mounted) return;

    final oldValue = _currentAmount;

    _amountAnim = Tween<double>(
      begin: oldValue,
      end: newValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller
      ..reset()
      ..forward();

    _previousAmount = oldValue;
    _currentAmount = newValue;
  }

  double get difference => _currentAmount - _previousAmount;

  double get percentage {
    if (_previousAmount == 0) {
      return _currentAmount == 0 ? 0 : 100;
    }

    return (difference / _previousAmount) * 100;
  }

  bool get isIncrease => difference >= 0;

  Color get trendColor => isIncrease ? Colors.greenAccent : Colors.redAccent;

  IconData get trendIcon =>
      isIncrease ? Icons.trending_up : Icons.trending_down;

  String get percentLabel =>
      "${isIncrease ? '+' : '-'}${percentage.abs().toStringAsFixed(1)}%";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: context.read<Datafeed>().dashboardMomoStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load ${context.read<Datafeed>().dashboardPeriodLabel} '
              'MOMO: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return _buildCard();
        }

        final momo = snapshot.data!;

        // Animate only when value changes
        if (momo != _currentAmount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && momo != _currentAmount) {
              _animateTo(momo);
              setState(() {});
            }
          });
        }

        return _buildCard();
      },
    );
  }

  Widget _buildCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: widget.cwidth,
      height: 235,
      padding: const EdgeInsets.all(16),
      decoration: _dashboardCardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total MOMO",
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.phone_android, color: trendColor, size: 16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          AnimatedBuilder(
            animation: _amountAnim,
            builder: (context, child) {
              return FittedBox(
                child: Text(
                  "GHS ${NumberFormat('#,##0.00').format(_amountAnim.value)}",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 6),

          Text(
            "Total for ${context.watch<Datafeed>().dashboardPeriodLabel}",
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),

          const Spacer(),

          // ======================================================
          // TREND
          // ======================================================
          Row(
            children: [
              Icon(trendIcon, color: trendColor, size: 15),

              const SizedBox(width: 4),

              Text(
                percentLabel,
                style: TextStyle(
                  color: trendColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(width: 6),

              Text(
                "vs previous",
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ======================================================
          // PROGRESS
          // ======================================================
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: min(percentage.abs() / 100, 1),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(trendColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

Widget _statCard({
  required BuildContext context,
  required String title,
  required String value,
  required String subtitle,
  required IconData icon,
  required Color iconColor,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    width: 200,
    padding: const EdgeInsets.all(12),
    decoration: _dashboardCardDecoration(colorScheme),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Icon
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            Icon(icon, color: iconColor, size: 20),
          ],
        ),

        const SizedBox(height: 4),

        // Value
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 4),

        // Subtitle
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
