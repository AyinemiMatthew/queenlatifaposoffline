import 'package:flutter/material.dart';
import 'package:kologsoft/models/productcategorymodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../providers/routes.dart';

class ProductCategoryReg extends StatefulWidget {
  final Productcategorymodel? category;
  const ProductCategoryReg({super.key, this.category});

  @override
  State<ProductCategoryReg> createState() => _ProductCategoryRegState();
}

class _ProductCategoryRegState extends State<ProductCategoryReg> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _categorynameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.category != null) {
      _categorynameController.text = widget.category!.productname;
    }
  }

  @override
  void dispose() {
    _categorynameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isLightTheme = Theme.of(context).brightness == Brightness.light;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.category != null
                  ? "EDIT PRODUCT CATEGORY"
                  : "PRODUCT CATEGORY REGISTRATION",
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onPrimary,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 700),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _categorynameController,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Category Name',
                                labelStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                filled: true,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Enter category name'
                                  : null,
                            ),
                            const SizedBox(height: 30),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                // Save button
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _isSaving
                                        ? null
                                        : () async {
                                            if (_isSaving) return;
                                            if (!_formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            final navigator = Navigator.of(
                                              context,
                                            );
                                            setState(() => _isSaving = true);
                                            try {
                                              final category =
                                                  Productcategorymodel(
                                                    id:
                                                        widget.category?.id ??
                                                        '',
                                                    productname:
                                                        _categorynameController
                                                            .text
                                                            .trim(),
                                                    staff: '',
                                                    companyid: value.companyid,
                                                    companyemail:
                                                        value.companyemail,
                                                    date: DateTime.now(),
                                                    updatedat: DateTime.now(),
                                                    deletedat: DateTime.now(),
                                                    updatedby: '',
                                                    deletedby: '',
                                                  );

                                              await value.addOrUpdateCategory(
                                                category,
                                              );

                                              if (!mounted) return;

                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    widget.category != null
                                                        ? 'Category updated successfully'
                                                        : 'Category saved successfully',
                                                  ),
                                                  backgroundColor:
                                                      colorScheme.primary,
                                                ),
                                              );

                                              if (widget.category != null) {
                                                navigator.pop();
                                              } else {
                                                _categorynameController.clear();
                                              }
                                            } catch (e) {
                                              if (!mounted) return;
                                              messenger.showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Operation failed: $e',
                                                  ),
                                                  backgroundColor:
                                                      colorScheme.error,
                                                ),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                  () => _isSaving = false,
                                                );
                                              }
                                            }
                                          },

                                    child: _isSaving
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                              ),
                                              const SizedBox(width: 10),
                                              const Text('Saving...'),
                                            ],
                                          )
                                        : Text(
                                            widget.category != null
                                                ? "Update"
                                                : "Add",
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isLightTheme
                                          ? colorScheme.primary
                                          : Colors.white70,
                                      side: BorderSide(
                                        color: isLightTheme
                                            ? colorScheme.outline
                                            : Colors.white70,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.view_list,
                                      color: isLightTheme
                                          ? colorScheme.primary
                                          : Colors.white70,
                                    ),
                                    label: Text(
                                      "View",
                                      style: TextStyle(
                                        color: isLightTheme
                                            ? colorScheme.primary
                                            : Colors.white70,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        Routes.productcateview,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}
