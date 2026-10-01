import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

import 'companyreg.dart';
import 'forgotpassword.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && mounted) {
      // User is already authenticated, restore session data
      final datafeed = Provider.of<Datafeed>(context, listen: false);

      try {
        // Just restore the session data, let RouteGuard handle navigation
        await datafeed.getdata();
      } catch (e) {
        debugPrint('Error restoring session: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLightTheme
                    ? [
                        colorScheme.surface,
                        colorScheme.surfaceContainerHighest,
                        colorScheme.surface,
                      ]
                    : const [
                        Color(0xFF0D1B2A),
                        Color(0xFF1B263B),
                        Color(0xFF415A77),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final loginCard = _buildLoginCard(value);

                  if (!isWide) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Center(child: loginCard),
                          const SizedBox(height: 24),
                          _buildLeftPanel(),
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(child: _buildLeftPanel()),
                      ),
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 24,
                            ),
                            child: loginCard,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginCard(Datafeed value) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final fieldFillColor = isLightTheme
        ? colorScheme.surfaceContainerHighest
        : const Color(0xFF273043);
    final fieldTextColor = isLightTheme ? colorScheme.onSurface : Colors.white;
    final fieldMutedColor = isLightTheme
        ? colorScheme.onSurfaceVariant
        : const Color(0xFFADB8C8);
    final fieldBorderColor = isLightTheme
        ? colorScheme.outline.withOpacity(0.8)
        : const Color(0xFF4F5F7A);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Login container
          Container(
            margin: const EdgeInsets.only(top: 72),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 56, 36, 36),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ...existing code (remove logo from here)
                        const SizedBox(height: 24),
                        Text(
                          'KologSoft POS',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: fieldTextColor),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Email',
                            labelStyle: TextStyle(color: fieldMutedColor),
                            hintStyle: TextStyle(color: fieldMutedColor),
                            floatingLabelStyle: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.secondary
                                  : fieldMutedColor,
                            ),
                            filled: true,
                            fillColor: fieldFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 1.1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isLightTheme
                                    ? colorScheme.primary
                                    : const Color(0xFF415A77),
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: fieldMutedColor,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Enter a valid email'
                              : null,
                          onSaved: (value) =>
                              _emailController.text = value ?? '',
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          style: TextStyle(color: fieldTextColor),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Password',
                            labelStyle: TextStyle(color: fieldMutedColor),
                            hintStyle: TextStyle(color: fieldMutedColor),
                            floatingLabelStyle: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.secondary
                                  : fieldMutedColor,
                            ),
                            filled: true,
                            fillColor: fieldFillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 1.1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: fieldBorderColor,
                                width: 1.1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isLightTheme
                                    ? colorScheme.primary
                                    : const Color(0xFF415A77),
                                width: 1.5,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: fieldMutedColor,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: fieldMutedColor,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) =>
                              value == null || value.length < 6
                              ? 'Password must be at least 6 characters'
                              : null,
                          onSaved: (value) =>
                              _passwordController.text = value ?? '',
                        ),
                        const SizedBox(height: 28),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF415A77),
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _loading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Please enter valid email and password.',
                                            style: TextStyle(
                                              color: colorScheme.onError,
                                            ),
                                          ),
                                          backgroundColor: colorScheme.error,
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      setState(() => _loading = true);

                                      await value.login(
                                        _emailController.text.trim(),
                                        _passwordController.text.trim(),
                                        context,
                                      );
                                      // Fetch VAT and store in SharedPreferences
                                      // await value.fetchAndStoreVat();
                                      //  Navigator.pushNamed(context, Routes.home);
                                    } catch (e) {
                                      print(e);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Login failed: ${e.toString()}',
                                          ),
                                          backgroundColor: colorScheme.error,
                                        ),
                                      );
                                    } finally {
                                      setState(() => _loading = false);
                                    }
                                  },
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: isLightTheme
                                  ? colorScheme.secondary
                                  : Colors.blue,
                            ),
                          ),
                        ),
                        // TextButton(
                        //   onPressed: () async {
                        //     //value.forgotPassword(_emailController.text.toString(), context);
                        //     await value.auth.sendPasswordResetEmail(
                        //       email: _emailController.text
                        //           .toString(),
                        //     );
                        //     //  _showForgotPasswordDialog(value);
                        //   },
                        //   child: const Text(
                        //     'Forgot password?',
                        //     style: TextStyle(color: Colors.white70),
                        //   ),
                        // ),

                        SizedBox(width: 5),

                        // TextButton(
                        //   onPressed: () async {
                        //     Navigator.push(context, MaterialPageRoute(
                        //       builder: (context) => const CompanyRegPage(),
                        //     ));
                        //   },
                        //
                        //   child: const Text(
                        //     'Company registration?',
                        //     style: TextStyle(color: Colors.white70),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Overlapping logo (50% inside the container)
          Positioned(
            top: 36, // Move logo down so half is inside
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF415A77),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/kposs.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Desktop left panel: product description
  Widget _buildLeftPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final features = <Map<String, dynamic>>[
      {
        'icon': Icons.point_of_sale,
        'title': 'Sales & POS',
        'desc': 'Fast checkout, multiple payment methods',
      },
      {
        'icon': Icons.inventory_2,
        'title': 'Stock & Inventory',
        'desc': 'Transfers, requests & stock levels',
      },
      {
        'icon': Icons.store,
        'title': 'Multi-Branch',
        'desc': 'Run several branches from one account',
      },
      {
        'icon': Icons.assignment_return,
        'title': 'Damages & Returns',
        'desc': 'Track returned and damaged stock',
      },
      {
        'icon': Icons.admin_panel_settings,
        'title': 'Role-Based Access',
        'desc': 'Control what each staff member can do',
      },
      {
        'icon': Icons.bar_chart,
        'title': 'Sales Reports',
        'desc': 'Staff, branch & payment breakdowns',
      },
      {
        'icon': Icons.print,
        'title': 'Receipt Printing',
        'desc': 'Silent printing straight to your printer',
      },
      {
        'icon': Icons.devices,
        'title': 'Any Device',
        'desc': 'Windows desktop, tablet or phone',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome Back to",
            style: TextStyle(
              color: isLightTheme ? colorScheme.onSurface : Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          Text(
            "KologSoft POS",
            style: TextStyle(
              color: isLightTheme
                  ? colorScheme.secondary
                  : Colors.lightBlueAccent,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "The all-in-one platform for sales, inventory, billing and multi-branch"
            "management software built for African businesses.",
            style: TextStyle(
              color: isLightTheme
                  ? colorScheme.onSurfaceVariant
                  : Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _StatBadge(label: "10-day", note: "FREE TRIAL"),
              _StatBadge(label: "Multi-Branch", note: "READY"),
              _StatBadge(label: "Windows +", note: "MOBILE"),
            ],
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = features
                  .map(
                    (f) => _buildFeatureTile(
                      f['icon'] as IconData,
                      f['title'] as String,
                      f['desc'] as String,
                    ),
                  )
                  .toList();

              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    for (final tile in tiles) ...[
                      tile,
                      if (tile != tiles.last) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String desc) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isLightTheme
                  ? colorScheme.primary
                  : const Color(0xFF273043),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isLightTheme ? colorScheme.onPrimary : Colors.white70,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10.5,
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

class _StatBadge extends StatelessWidget {
  final String label;
  final String note;
  const _StatBadge({required this.label, required this.note});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isLightTheme
                ? colorScheme.secondary
                : Colors.lightBlueAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          note,
          style: TextStyle(
            color: isLightTheme ? colorScheme.onSurfaceVariant : Colors.white38,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
