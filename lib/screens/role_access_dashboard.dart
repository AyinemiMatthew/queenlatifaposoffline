import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';
import '../providers/routes.dart';
import '../paymentwidgets/showlogout.dart';
import '../providers/theme_provider.dart';
import 'role_access_config.dart';

class RoleAccessDashboard extends StatefulWidget {
  const RoleAccessDashboard({super.key});

  @override
  State<RoleAccessDashboard> createState() => _RoleAccessDashboardState();
}

class _RoleAccessDashboardState extends State<RoleAccessDashboard> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late Future<Map<String, double>> _todayTotals;
  @override
  void initState() {
    super.initState();
    _todayTotals = context.read<Datafeed>().fetchStaffTotalSalesToday();
    Future.microtask(() {
      if (!mounted) return;
      final datafeed = context.read<Datafeed>();
      if (datafeed.roleAccessSelections == null &&
          !datafeed.roleAccessLoading &&
          !datafeed.roleAccessError) {
        datafeed.loadRoleAccessSelections();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<RoleAccessAction>> _groupActions(
    List<RoleAccessAction> actions,
  ) {
    final Map<String, List<RoleAccessAction>> groups = {'All': actions};

    for (final action in actions) {
      final category = action.badge.isNotEmpty ? action.badge : 'General';
      if (!groups.containsKey(category)) {
        groups[category] = [];
      }
      groups[category]!.add(action);
    }

    return groups;
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
                constraints: const BoxConstraints(maxWidth: 420),
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
                                color: colorScheme.primary.withValues(
                                  alpha: 0.1,
                                ),
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
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Update your account password',
                                    style: theme.textTheme.bodyMedium?.copyWith(
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
                              color: colorScheme.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              color: colorScheme.onPrimary,
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
                            fillColor: colorScheme.surfaceContainerHighest,
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
                              color: colorScheme.primary,
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
                            fillColor: colorScheme.surfaceContainerHighest,
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
                              color: colorScheme.primary,
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
                            fillColor: colorScheme.surfaceContainerHighest,
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
                                                ),
                                                backgroundColor:
                                                    colorScheme.primary,
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
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    colorScheme.error,
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
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
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
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext parentcontext) {
    LogoutDialog.show(parentcontext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final datafeed = context.watch<Datafeed>();
    final roleLabel = _formatRoleName(datafeed.accesslevel);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final isLoading =
        datafeed.roleAccessLoading && datafeed.roleAccessSelections == null;
    final hasError =
        datafeed.roleAccessError && datafeed.roleAccessSelections == null;

    final selections =
        datafeed.roleAccessSelections ??
        (isLoading
            ? const <String, List<String>>{}
            : getDefaultRoleAccessSelections());

    final allActions = isLoading
        ? const <RoleAccessAction>[]
        : buildRoleAccessActions(
            datafeed.accesslevel,
            roleSelections: selections,
          );

    final groupedActions = _groupActions(allActions);
    final categories = groupedActions.keys.toList()
      ..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    if (!_selectedCategory.contains('All') &&
        !categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }

    final currentActions = groupedActions[_selectedCategory] ?? [];
    final filteredActions = currentActions.where((action) {
      return action.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          action.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: !isDesktop
          ? _buildSidebar(context, categories, datafeed, roleLabel)
          : null,
      body: Row(
        children: [
          if (isDesktop)
            _buildSidebar(context, categories, datafeed, roleLabel),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, datafeed, isDesktop),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : hasError
                      ? _buildErrorState(datafeed, colorScheme)
                      : allActions.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildContentArea(
                          context,
                          filteredActions,
                          theme,
                          isDesktop,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<String> categories,
    Datafeed datafeed,
    String roleLabel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return SizedBox(
      width: 260,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dashboard_rounded,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    datafeed.company.isEmpty
                        ? 'KOLOG POS'
                        : datafeed.company.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Command Center',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'CATEGORIES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      selected: isSelected,
                      selectedTileColor: colorScheme.primary.withOpacity(0.1),
                      leading: Icon(
                        _getCategoryIcon(cat),
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      title: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        if (!isDesktop) Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            Divider(color: colorScheme.outlineVariant, height: 1),
            _buildSidebarProfile(context, datafeed, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarProfile(
    BuildContext context,
    Datafeed datafeed,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Routes.staffprofile),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.secondary,
                child: Text(
                  datafeed.staff.isNotEmpty
                      ? datafeed.staff[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: colorScheme.onSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      datafeed.staff.isEmpty ? 'User' : datafeed.staff,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatRoleName(datafeed.accesslevel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Datafeed datafeed, bool isDesktop) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const SizedBox(width: 8),
          // Expanded(child: _buildTopBarTotals()),
          Expanded(
            child: Container(
              height: 44,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          //  const Spacer(),
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
                await context.read<ThemeProvider>().toggleTheme();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not save theme preference: $error'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: colorScheme.error),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
          const SizedBox(width: 8),
          _buildTopBarProfile(context, datafeed),
        ],
      ),
    );
  }

  Widget _buildTopBarProfile(BuildContext context, Datafeed datafeed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          VerticalDivider(
            width: 32,
            indent: 20,
            endIndent: 20,
            color: colorScheme.outlineVariant,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                datafeed.staff.isEmpty ? 'User' : datafeed.staff,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                datafeed.company.isEmpty ? 'Kolog POS' : datafeed.company,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'password',
          child: Row(
            children: [
              Icon(
                Icons.lock_reset_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('Change Password'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              const Text('My Profile'),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'password') _showChangePasswordDialog(context, datafeed);
        if (val == 'profile') Navigator.pushNamed(context, Routes.staffprofile);
      },
    );
  }

  Widget _buildTopBarTotals() {
    return FutureBuilder<Map<String, double>>(
      future: _todayTotals,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final t = snap.data!;

        Widget chip(String label, String key, Color color) {
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  (t[key] ?? 0).toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('Cash', 'cash', Colors.green),
              chip('MoMo', 'momo', Colors.orange),
              chip('Credit', 'creditSales', Colors.red),
              chip('Debt', 'debtPayment', Colors.blue),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentArea(
    BuildContext context,
    List<RoleAccessAction> actions,
    ThemeData theme,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _selectedCategory,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${actions.length}',
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isDesktop ? 340 : 400,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 2.2,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              return _buildModernTile(context, actions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModernTile(BuildContext context, RoleAccessAction action) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (action.route.isNotEmpty) {
              Navigator.pushNamed(context, action.route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, color: action.color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.grid_view_rounded;
      case 'entry':
        return Icons.add_circle_outline_rounded;
      case 'report':
        return Icons.bar_chart_rounded;
      case 'view':
        return Icons.visibility_outlined;
      case 'account':
        return Icons.account_balance_wallet_outlined;
      case 'branch':
        return Icons.storefront_rounded;
      case 'read/write':
        return Icons.edit_note_rounded;
      case 'home':
        return Icons.home_repair_service_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildErrorState(Datafeed datafeed, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Connection lost or data error',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          TextButton(
            onPressed: () => datafeed.loadRoleAccessSelections(force: true),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No modules assigned to your role',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRoleName(String accessLevel) {
    final normalized = accessLevel.trim();
    if (normalized.isEmpty) return 'User';
    return normalized.replaceAll(' ', ' ');
  }
}
