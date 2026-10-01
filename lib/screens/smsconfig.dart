import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';
import '../models/suppliermodel.dart';

class SmsConfiguration extends StatefulWidget {
  final SMSCONFIG? configuration;
  const SmsConfiguration({super.key, this.configuration});

  @override
  State<SmsConfiguration> createState() => _SmsConfigurationState();
}

class _SmsConfigurationState extends State<SmsConfiguration> {
  final _formKey = GlobalKey<FormState>();

  final _senderid = TextEditingController();
  final smsKey = TextEditingController();

  bool _isSubmitting = false;
  bool _senderIdLocked = false;
  bool _smsKeyLocked = false;
  bool _loadingConfig = true;

  // Provider selection
  String _selectedProvider = 'Kologsoft';
  final List<String> _providers = [
    'Kologsoft',
    'MNotify',
    'Hubtel',
    'Termii',
    'Africa\'s Talking',
  ];

  String? validateField(String? value, {required String type}) {
    final v = value?.trim() ?? '';

    final validators = <String, String? Function(String)>{
      'text': (val) => val.isEmpty ? 'Required' : null,
      'phone': (val) {
        if (val.isEmpty) return 'Phone number is required';
        if (!RegExp(r'^\+?[0-9]+$').hasMatch(val))
          return 'Enter a valid phone number';
        final length = val.replaceAll('+', '').length;
        if (length < 9 || length > 15) return 'Enter a valid phone number';
        return null;
      },
      'email': (val) {
        if (val.isEmpty) return 'Email is required';
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val))
          return 'Enter a valid email';
        return null;
      },
    };

    final validator = validators[type];
    if (validator != null) return validator(v);

    return null;
  }

  @override
  void initState() {
    super.initState();
    _senderid.addListener(() {
      if (mounted) setState(() {});
    });

    smsKey.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSmsConfig();
    });
    if (widget.configuration != null) {
      _senderid.text = widget.configuration!.senderid;
      smsKey.text = widget.configuration!.key;
      _selectedProvider = widget.configuration!.provider ?? 'Kologsoft';
      _senderIdLocked = true;
      _smsKeyLocked = true;
    }
  }

  @override
  void dispose() {
    _senderid.dispose();
    smsKey.dispose();
    super.dispose();
  }

  Future<void> _loadSmsConfig() async {
    final datafeed = Provider.of<Datafeed>(context, listen: false);

    try {
      await datafeed.getdata();
      final snapshot = await FirebaseFirestore.instance
          .collection('sms_config')
          .where('companyid', isEqualTo: datafeed.companyid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();

        _senderid.text = data['senderid'] ?? '';
        smsKey.text = data['key'] ?? '';
        _selectedProvider = data['provider'] ?? 'Kologsoft';

        _senderIdLocked = _senderid.text.isNotEmpty;
        _smsKeyLocked = smsKey.text.isNotEmpty;
      } else {
        _senderIdLocked = false;
        _smsKeyLocked = false;
      }
    } catch (e) {
      debugPrint('Error loading SMS config: $e');
    }

    if (mounted) {
      setState(() {
        _loadingConfig = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final formWidth = screenWidth > 900
        ? screenWidth * 0.6
        : screenWidth * 0.95;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : Colors.black87;
    final secondaryForegroundColor = isDark ? Colors.white70 : Colors.black54;
    final subtleForegroundColor = isDark ? Colors.white54 : Colors.black45;
    final fieldFillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF5F7FA);
    final fieldBorderColor = isDark ? Colors.white12 : Colors.black12;

    return Consumer<Datafeed>(
      builder: (context, value, child) {
        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0A0F1E)
              : Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              'SMS Configuration',
              style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: foregroundColor,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF0F1A2E), Color(0xFF1A2744)]
                      : const [Colors.white, Color(0xFFF5F7FA)],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Container(
                    width: formWidth,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? null
                          : Theme.of(context).colorScheme.surface,
                      gradient: isDark
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1A2744), Color(0xFF223456)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: fieldBorderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.blueAccent,
                                      Colors.purpleAccent,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.sms_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SMS Gateway Setup',
                                    style: TextStyle(
                                      color: foregroundColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Configure your SMS provider settings',
                                    style: TextStyle(
                                      color: secondaryForegroundColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Provider Dropdown
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: fieldBorderColor),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _providers.contains(_selectedProvider)
                                  ? _selectedProvider
                                  : _providers.first,
                              dropdownColor: isDark
                                  ? const Color(0xFF1A2744)
                                  : Colors.white,
                              style: TextStyle(
                                color: foregroundColor,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'SMS Provider',
                                labelStyle: TextStyle(
                                  color: secondaryForegroundColor,
                                ),
                                floatingLabelStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : secondaryForegroundColor,
                                ),
                                prefixIcon: Icon(
                                  Icons.cloud_queue_rounded,
                                  color: subtleForegroundColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: secondaryForegroundColor,
                              ),
                              items: _providers.map((provider) {
                                return DropdownMenuItem<String>(
                                  value: provider,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getProviderIcon(provider),
                                        color: _getProviderColor(provider),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        provider,
                                        style: TextStyle(
                                          color: foregroundColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedProvider = value;
                                  });
                                }
                              },
                              validator: (value) => value == null
                                  ? 'Please select a provider'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Sender ID
                          TextFormField(
                            controller: _senderid,
                            readOnly: _senderIdLocked,
                            cursorColor: Colors.blueAccent,
                            style: TextStyle(color: foregroundColor),
                            decoration:
                                _inputDecoration(
                                  'Sender ID',
                                  Icons.storefront_rounded,
                                  isDark: isDark,
                                ).copyWith(
                                  suffixIcon: _senderIdLocked
                                      ? IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _senderid.clear();
                                              _senderIdLocked = false;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                            validator: (v) => validateField(v, type: 'text'),
                          ),
                          const SizedBox(height: 16),

                          // API Key
                          TextFormField(
                            controller: smsKey,
                            readOnly: _smsKeyLocked,
                            cursorColor: Colors.blueAccent,
                            style: TextStyle(color: foregroundColor),
                            obscureText: true,
                            decoration:
                                _inputDecoration(
                                  'API Key / Secret',
                                  Icons.key_rounded,
                                  isDark: isDark,
                                ).copyWith(
                                  suffixIcon: _smsKeyLocked
                                      ? IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              smsKey.clear();
                                              _smsKeyLocked = false;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                            validator: (v) => validateField(v, type: 'text'),
                          ),
                          const SizedBox(height: 8),

                          // Help text
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blueAccent.withOpacity(0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blueAccent.withOpacity(0.6),
                                  size: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Your API key is encrypted and stored securely.',
                                    style: TextStyle(
                                      color: secondaryForegroundColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Status indicators
                          if (_senderIdLocked && _smsKeyLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Configuration active',
                                    style: TextStyle(
                                      color: Colors.green.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.transparent
                                        : const Color(0xFFF1F5F9),
                                    foregroundColor: foregroundColor,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.black26,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () async {
                                          if (!_formKey.currentState!
                                                  .validate() ||
                                              _isSubmitting)
                                            return;
                                          setState(() => _isSubmitting = true);

                                          final nameInput = _senderid.text
                                              .trim();

                                          final query = await value.db
                                              .collection('sms_config')
                                              .where(
                                                'senderid',
                                                isEqualTo: nameInput,
                                              )
                                              .where(
                                                'companyid',
                                                isEqualTo: value.companyid,
                                              )
                                              .limit(1)
                                              .get();

                                          if (query.docs.isNotEmpty &&
                                              query.docs.first.id !=
                                                  widget.configuration?.id) {
                                            setState(
                                              () => _isSubmitting = false,
                                            );

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                  'Duplicate record',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          final id =
                                              widget.configuration?.id ??
                                              value.companyid;

                                          final smsconfig = SMSCONFIG(
                                            id: widget.configuration?.id ?? id,
                                            senderid: _senderid.text.trim(),
                                            key: smsKey.text.trim(),
                                            provider: _selectedProvider,
                                            company: value.company,
                                            companyid: value.companyid,
                                            datecreated: Timestamp.now(),
                                            staff: value.staff,
                                          );

                                          await FirebaseFirestore.instance
                                              .collection('sms_config')
                                              .doc(id)
                                              .set(smsconfig.toMap());

                                          setState(() {
                                            _isSubmitting = false;
                                            _senderIdLocked = true;
                                            _smsKeyLocked = true;
                                          });

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.green,
                                              content: Text(
                                                widget.configuration == null
                                                    ? 'Configuration saved successfully'
                                                    : 'Configuration updated successfully',
                                              ),
                                            ),
                                          );

                                          if (!mounted) return;
                                          if (widget.configuration?.id !=
                                              null) {
                                            Navigator.pop(context);
                                          }
                                        },
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              widget.configuration == null
                                                  ? Icons.save_rounded
                                                  : Icons.update_rounded,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              widget.configuration == null
                                                  ? 'Save Configuration'
                                                  : 'Update Configuration',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    required bool isDark,
  }) {
    final secondaryForegroundColor = isDark ? Colors.white70 : Colors.black54;
    final fieldFillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFF5F7FA);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: secondaryForegroundColor),
      floatingLabelStyle: TextStyle(
        color: isDark ? Colors.white : secondaryForegroundColor,
      ),
      hintStyle: TextStyle(color: secondaryForegroundColor),
      prefixIcon: Icon(icon, color: secondaryForegroundColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black26),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
      fillColor: fieldFillColor,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  IconData _getProviderIcon(String provider) {
    switch (provider) {
      case 'Kologsoft':
        return Icons.android_rounded;
      case 'MNotify':
        return Icons.notifications_active_rounded;
      case 'Hubtel':
        return Icons.phone_android_rounded;
      case 'Termii':
        return Icons.terminal_rounded;
      case 'Africa\'s Talking':
        return Icons.public_rounded;
      default:
        return Icons.cloud_queue_rounded;
    }
  }

  Color _getProviderColor(String provider) {
    switch (provider) {
      case 'Kologsoft':
        return Colors.blueAccent;
      case 'MNotify':
        return Colors.greenAccent;
      case 'Hubtel':
        return Colors.orangeAccent;
      case 'Termii':
        return Colors.purpleAccent;
      case 'Africa\'s Talking':
        return Colors.yellowAccent;
      default:
        return Colors.grey;
    }
  }
}
