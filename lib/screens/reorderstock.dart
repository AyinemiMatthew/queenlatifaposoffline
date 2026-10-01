import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/Datafeed.dart';

class ReorderLevelPage extends StatefulWidget {
  const ReorderLevelPage({Key? key}) : super(key: key);

  @override
  State<ReorderLevelPage> createState() => _ReorderLevelPageState();
}

class _ReorderLevelPageState extends State<ReorderLevelPage> {
  late TextEditingController _controller;

  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    final datafeed = context.read<Datafeed>();

    _controller = TextEditingController(
      text: datafeed.reorderLevel.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.trim());

    if (value == null) {
      setState(() {
        _errorText = 'Enter a valid number';
      });
      return;
    }

    if (value < 0) {
      setState(() {
        _errorText = 'Reorder level cannot be negative';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await context.read<Datafeed>().setReorderLevel(value);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reorder level set to ${value.toStringAsFixed(0)}',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = 'Could not save: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final datafeed = context.watch<Datafeed>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foregroundColor = isDark ? Colors.white : Colors.black87;
    final secondaryForegroundColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Reorder Level'),
        backgroundColor: isDark
            ? Theme.of(context).scaffoldBackgroundColor
            : Theme.of(context).colorScheme.surface,
        foregroundColor: foregroundColor,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),

            child: Card(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reorder Level',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: foregroundColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Set the minimum stock quantity that should trigger a reorder warning.',
                      style: TextStyle(
                        color: secondaryForegroundColor,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'Current reorder level',
                      style: TextStyle(
                        color: secondaryForegroundColor,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      datafeed.reorderLevel.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),

                    const SizedBox(height: 30),

                    TextField(
                      controller: _controller,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'New reorder level',
                        hintText: 'Enter quantity',
                        labelStyle: TextStyle(color: secondaryForegroundColor),
                        floatingLabelStyle: TextStyle(
                          color: isDark
                              ? Colors.white
                              : secondaryForegroundColor,
                        ),
                        hintStyle: TextStyle(color: secondaryForegroundColor),
                        prefixIcon: Icon(
                          Icons.tune,
                          color: secondaryForegroundColor,
                        ),
                        errorText: _errorText,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF22304A)
                            : Colors.white,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Items with a balance above 0 up to this number '
                      'will show as Reorder.',
                      style: TextStyle(
                        color: secondaryForegroundColor,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _saving ? 'Saving...' : 'Save Reorder Level',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
