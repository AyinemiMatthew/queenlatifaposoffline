import 'dart:async';

import 'package:flutter/foundation.dart' hide Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kologsoft/screens/uploadreceiptview.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import '../providers/item_provider.dart';
import '../providers/Datafeed.dart';

String normalizeReceiptDescription(String value) =>
    ItemProvider.normalizeReceiptDescription(value);

class ReceiptUploadPage extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? item;

  const ReceiptUploadPage({Key? key, this.docId, this.item}) : super(key: key);

  @override
  State<ReceiptUploadPage> createState() => _ReceiptUploadPageState();
}

class _ReceiptUploadPageState extends State<ReceiptUploadPage> {
  Color get _outlineColor => Theme.of(context).colorScheme.outline;
  Color get _fieldSurfaceColor =>
      Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : Theme.of(context).colorScheme.surfaceContainerHighest;

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor =>
      _isLightTheme ? Theme.of(context).colorScheme.onSurface : Colors.white;
  Color get _secondaryTextColor => _isLightTheme
      ? Theme.of(context).colorScheme.onSurfaceVariant
      : Colors.white70;
  Color get _dividerColor => _isLightTheme
      ? Theme.of(context).colorScheme.outlineVariant
      : Colors.white24;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<Uint8List> _logoBytesList = [];
  final List<File> _logoFileList = [];
  List<String> _existingLogoUrls = [];
  static const int _maxImages = 10;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {});

    if (widget.item != null) {
      final d = widget.item!;
      _nameController.text = d['name'] ?? '';
      _descriptionController.text = normalizeReceiptDescription(
        (d['description'] ?? '').toString(),
      );
      _existingLogoUrls = List<String>.from(d['receiptUrl'] ?? []);
      print(widget.docId);
    }
  }

  Future<void> pickLogo() async {
    final totalExisting =
        _existingLogoUrls.length + _logoFileList.length + _logoBytesList.length;

    if (totalExisting >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxImages images allowed.')),
      );
      return;
    }

    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 85,
    );
    if (pickedFiles.isEmpty) return;

    final List<String> errors = [];
    int added = 0;

    for (final file in pickedFiles) {
      if ((totalExisting + added) >= _maxImages) {
        errors.add('Limit of $_maxImages images reached. Some were skipped.');
        break;
      }

      final bytes = await file.readAsBytes();
      final filename = file.name;
      final error = context.read<ItemProvider>().validateReceiptImage(
        bytes,
        filename,
      );

      if (error != null) {
        errors.add(error);
        continue;
      }

      if (kIsWeb) {
        _logoBytesList.add(bytes);
      } else {
        _logoFileList.add(File(file.path));
      }
      added++;
    }

    if (errors.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errors.join('\n')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() {});
  }

  Future<void> _savereceipt() async {
    if (!_formKey.currentState!.validate()) return;

    final bool hasNewImages =
        _logoFileList.isNotEmpty || _logoBytesList.isNotEmpty;
    final bool hasAnyImages = hasNewImages || _existingLogoUrls.isNotEmpty;

    if (!hasAnyImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload an image',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final datafeed = context.read<Datafeed>();
      await context.read<ItemProvider>().saveReceipt(
        ReceiptUploadRequest(
          datafeed: datafeed,
          receiptNumber: _nameController.text,
          description: _descriptionController.text,
          existingId: widget.docId,
          existingReceipt: widget.item,
          keptReceiptUrls: List<String>.from(_existingLogoUrls),
          imageFiles: List<File>.from(_logoFileList),
          imageBytes: List<Uint8List>.from(_logoBytesList),
        ),
      );
      _nameController.clear();
      _descriptionController.clear();
      setState(() {
        _logoBytesList.clear();
        _logoFileList.clear();
        _existingLogoUrls.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.docId == null
                ? 'Saved successfully!'
                : 'Updated successfully!',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.docId != null) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (context, datafeed, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.docId == null
                  ? 'Upload Receipt'
                  : 'Edit ${_nameController.text}',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.view_list),
                color: colorScheme.primary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const uploadReceiptViewPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          body: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      SizedBox(
                        child: _buildField(
                          enabled: widget.docId == null,
                          _nameController,
                          'Company / Receipt No.',
                          Icons.label,

                          onChanged: (v) {
                            _formKey.currentState!.validate();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        child: _buildField(
                          _descriptionController,
                          'Description',
                          Icons.description_outlined,
                          required: false,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(child: _imagePickerSection()),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLightTheme
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF405A78),
                            foregroundColor: _isLightTheme
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _loading ? null : _savereceipt,
                          child: _loading
                              ? CircularProgressIndicator(
                                  color: colorScheme.onPrimary,
                                )
                              : const Text('Save'),
                        ),
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
  }

  TextFormField _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool enabled = true,
    bool isNumber = false,
    bool required = true,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      enabled: enabled,
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: _textColor),

      validator: (value) {
        if (validator != null) {
          return validator(value);
        }

        if (!required) return null;

        if (value == null || value.isEmpty) {
          return 'Required';
        }

        return null;
      },

      decoration: _inputDecoration(label, icon),
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      filled: true,
      fillColor: _fieldSurfaceColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _imagePickerSection() {
    bool hasImage =
        _logoBytesList.isNotEmpty ||
        _logoFileList.isNotEmpty ||
        _existingLogoUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),

        //  MULTIPLE IMAGE GRID
        GestureDetector(
          onTap: pickLogo,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _fieldSurfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.green : _outlineColor,
                width: hasImage ? 2 : 1,
              ),
            ),
            child: hasImage
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Memory images (web)
                      ..._logoBytesList.asMap().entries.map((entry) {
                        int index = entry.key;
                        Uint8List img = entry.value;

                        return Stack(
                          children: [
                            Image.memory(
                              img,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _logoBytesList.removeAt(index);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      // File images (mobile)
                      ..._logoFileList.asMap().entries.map((entry) {
                        int index = entry.key;
                        File file = entry.value;

                        return Stack(
                          children: [
                            Image.file(
                              file,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _logoFileList.removeAt(index);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      // Existing network images
                      ..._existingLogoUrls.asMap().entries.map((entry) {
                        int index = entry.key;
                        String url = entry.value;

                        return Stack(
                          children: [
                            Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  // Delete from Storage immediately when user taps Ã—
                                  try {
                                    await context
                                        .read<ItemProvider>()
                                        .deleteReceiptImages([url]);
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not delete image: $error',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!mounted) return;
                                  setState(() {
                                    _existingLogoUrls.removeAt(index);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  )
                : SizedBox(
                    height: 120,
                    child: Center(
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 50,
                        color: _secondaryTextColor,
                      ),
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 8),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: pickLogo,
              icon: Icon(hasImage ? Icons.add : Icons.upload, size: 18),
              label: Text(hasImage ? 'Add More' : 'Select Images'),
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
            ),

            if (hasImage) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () async {
                  // Delete all existing Storage files, then clear local lists
                  if (_existingLogoUrls.isNotEmpty) {
                    try {
                      await context.read<ItemProvider>().deleteReceiptImages(
                        List<String>.from(_existingLogoUrls),
                      );
                    } catch (error) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not delete images: $error'),
                        ),
                      );
                      return;
                    }
                  }
                  if (!mounted) return;
                  setState(() {
                    _logoBytesList.clear();
                    _logoFileList.clear();
                    _existingLogoUrls.clear();
                  });
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Remove All'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
