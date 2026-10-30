import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MomoPaymentFields extends StatelessWidget {
  final String? selectedNetwork;
  final String? momoType;

  final List<String> networks;

  final ValueChanged<String?> onNetworkChanged;
  final ValueChanged<String?> onMomoTypeChanged;

  final Widget? merchantFields;

  final TextEditingController? phoneController;
  final Color fieldColor;
  final Color foregroundColor;
  final Color mutedColor;
  final Color borderColor;
  final Color floatingLabelColor;

  const MomoPaymentFields({
    super.key,
    required this.selectedNetwork,
    required this.momoType,
    required this.networks,
    required this.onNetworkChanged,
    required this.onMomoTypeChanged,
    this.merchantFields,
    this.phoneController,
    required this.fieldColor,
    required this.foregroundColor,
    required this.mutedColor,
    required this.borderColor,
    required this.floatingLabelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildNetworkDropdown(context),
        const SizedBox(height: 10),
        _buildMomoTypeDropdown(context),

        const SizedBox(height: 5),

        // Merchant fields
        if (momoType == 'merchant' && merchantFields != null) ...[
          const SizedBox(height: 5),
          merchantFields!,
        ],

        // Hubtel phone
        if (momoType == 'hubtel' && phoneController != null) ...[
          const SizedBox(height: 8),
          _buildPhoneField(context),
        ],
      ],
    );
  }

  Widget _buildNetworkDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedNetwork,
      isExpanded: true,
      dropdownColor: fieldColor,
      style: TextStyle(color: foregroundColor),
      decoration: _dropdownDecoration(
        label: 'Select Network',
        prefix: Icons.sim_card,
      ),
      items: networks.map((network) {
        return DropdownMenuItem<String>(
          value: network.toLowerCase(),
          child: Row(
            children: [
              Icon(
                _getNetworkIcon(network),
                color: _getNetworkColor(network),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(network, style: TextStyle(color: foregroundColor)),
            ],
          ),
        );
      }).toList(),
      onChanged: onNetworkChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a network';
        }

        return null;
      },
    );
  }

  Widget _buildMomoTypeDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: momoType,
      isExpanded: true,
      dropdownColor: fieldColor,
      style: TextStyle(color: foregroundColor),
      decoration: _dropdownDecoration(
        label: 'Payment Type',
        prefix: Icons.account_balance_wallet,
      ),
      items: [
        DropdownMenuItem(
          value: 'hubtel',
          child: Text('Hubtel', style: TextStyle(color: foregroundColor)),
        ),
        DropdownMenuItem(
          value: 'merchant',
          child: Text('Merchant', style: TextStyle(color: foregroundColor)),
        ),
      ],
      onChanged: onMomoTypeChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select payment type';
        }

        return null;
      },
    );
  }

  Widget _buildPhoneField(BuildContext context) {
    return TextFormField(
      controller: phoneController,
      style: TextStyle(color: foregroundColor),
      decoration: _inputDecoration(
        label: 'Phone Number',
        prefix: Icons.phone,
        hint: 'Enter contact number',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
        LengthLimitingTextInputFormatter(13),
      ],
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return 'Required';
        }

        final cleaned = v.replaceAll(' ', '');

        // +233XXXXXXXXX
        if (cleaned.startsWith('+233')) {
          if (cleaned.length != 13 ||
              !RegExp(r'^\+233\d{9}$').hasMatch(cleaned)) {
            return 'Invalid format. Use +233XXXXXXXXX';
          }
        }
        // 0XXXXXXXXX
        else if (cleaned.startsWith('0')) {
          if (cleaned.length != 10 || !RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
            return 'Invalid format. Use 0XXXXXXXXX';
          }
        } else {
          return 'Phone must start with 0 or +233';
        }

        return null;
      },
    );
  }

  IconData _getNetworkIcon(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Icons.sim_card;

      case 'vodafone':
        return Icons.sim_card;

      case 'airteltigo':
        return Icons.sim_card;

      default:
        return Icons.sim_card;
    }
  }

  Color _getNetworkColor(String network) {
    switch (network.toLowerCase()) {
      case 'mtn':
        return Colors.yellow;

      case 'vodafone':
        return Colors.red;

      case 'airteltigo':
        return Colors.blue;

      default:
        return Colors.grey;
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData prefix,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: mutedColor),
      floatingLabelStyle: TextStyle(color: floatingLabelColor),
      hintText: hint,
      hintStyle: TextStyle(color: mutedColor),
      prefixIcon: Icon(prefix, color: mutedColor),
      filled: true,
      fillColor: fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  InputDecoration _dropdownDecoration({
    required String label,
    required IconData prefix,
  }) {
    return _inputDecoration(label: label, prefix: prefix, hint: '');
  }
}
