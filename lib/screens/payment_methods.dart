import 'package:flutter/material.dart';

class PaymentMethods extends StatefulWidget {
  const PaymentMethods({super.key});

  @override
  State<PaymentMethods> createState() => _PaymentMethodsState();
}

class _PaymentMethodsState extends State<PaymentMethods> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subTypeController = TextEditingController();

  String? _selectedSubtype;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final pageColor = isDark ? const Color(0xFF101624) : colorScheme.surface;
    final appBarColor = isDark ? const Color(0xFF0D1A26) : colorScheme.surface;
    final cardColor = isDark ? const Color(0xFF182232) : colorScheme.surface;
    final fieldColor = isDark
        ? const Color(0xFF22304A)
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = isDark ? Colors.white : colorScheme.onSurface;
    final secondaryColor = isDark
        ? Colors.white70
        : colorScheme.onSurfaceVariant;
    final borderColor = isDark ? Colors.white24 : colorScheme.outlineVariant;
    final subtleBorderColor = isDark
        ? Colors.white12
        : colorScheme.outlineVariant;
    final buttonForegroundColor = isDark ? Colors.white : colorScheme.onPrimary;
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        title: Text("Add Payment Method"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: foregroundColor),
                      decoration: InputDecoration(
                        labelText: "Method Name",
                        hintText: "Enter payment method name",
                        labelStyle: TextStyle(color: secondaryColor),
                        hintStyle: TextStyle(color: secondaryColor),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: subtleBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: subtleBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextFormField(),
                    SizedBox(height: 10),
                    DropdownButtonFormField(
                      value: _selectedSubtype,
                      dropdownColor: fieldColor,
                      style: TextStyle(color: foregroundColor),
                      decoration: InputDecoration(
                        labelText: 'Choose Account',
                        labelStyle: TextStyle(color: secondaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        fillColor: fieldColor,
                        filled: true,
                      ),
                      items: [],
                      onChanged: (value) {},
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: [
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {},
                              child: Text(
                                'Add',
                                style: TextStyle(color: buttonForegroundColor),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: secondaryColor),
                                ),
                              ),
                              onPressed: () {
                                //Navigator.pushNamed(context, Routes.accountTypeView);
                              },
                              child: Text(
                                "View",
                                style: TextStyle(color: foregroundColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
