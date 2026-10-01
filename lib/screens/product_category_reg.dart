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
  @override
  void initState() {
    super.initState();

    if (widget.category != null) {
      _categorynameController.text = widget.category!.productname;
    }
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).colorScheme.primary,
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
                                      backgroundColor: Colors.blue,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (!_formKey.currentState!.validate())
                                        return;

                                      try {
                                        final category = Productcategorymodel(
                                          id: widget.category?.id ?? '',
                                          productname: _categorynameController
                                              .text
                                              .trim(),
                                          staff: '',
                                          companyid: value.companyid,
                                          companyemail: value.companyemail,
                                          date: DateTime.now(),
                                          updatedat: DateTime.now(),
                                          deletedat: DateTime.now(),
                                          updatedby: '',
                                          deletedby: '',
                                        );

                                        await value.addOrUpdateCategory(
                                          category,
                                        );

                                        if (widget.category != null) {
                                          Navigator.pop(context);
                                        }

                                        _categorynameController.clear();

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              widget.category != null
                                                  ? 'Category updated successfully'
                                                  : 'Category saved successfully',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Operation failed: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },

                                    child: Text(
                                      widget.category != null
                                          ? "Update"
                                          : "Add",
                                      style: TextStyle(color: Colors.white),
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
