import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/screens/stockingmode_list.dart';
import 'package:provider/provider.dart';

import '../models/stocking_modeModel.dart';
import '../providers/Datafeed.dart';
import 'ReturnReasonList.dart';

class ReturnReasons extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? data;
  const ReturnReasons({Key? key, this.docId, this.data}) : super(key: key);

  @override
  State<ReturnReasons> createState() => _ReturnReasonsState();
}

class _ReturnReasonsState extends State<ReturnReasons> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  @override
  initState() {
    super.initState();
    if (widget.data != null) {
      _nameController.text = widget.data!['name'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final colorScheme = Theme.of(context).colorScheme;
        final formWidth = screenWidth > 900
            ? screenWidth * 0.6
            : screenWidth * 0.95;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.docId != null ? "Edit Reason" : "Register Reasons",
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onPrimary,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
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
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameController,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  labelStyle: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.mode,
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
                                    ? 'Enter reason'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              const SizedBox(height: 32),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: 200,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.secondary,
                                        foregroundColor: colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              if (!_formKey.currentState!
                                                  .validate())
                                                return;
                                              setState(() => _isLoading = true);
                                              final name = _nameController.text
                                                  .trim();
                                              String docid = value
                                                  .normalizeAndSanitize(
                                                    "${value.companyid}${name}",
                                                  );
                                              final id = widget.docId ?? docid;

                                              try {
                                                cropModel newMode = cropModel(
                                                  name: name,
                                                  staff: value.staff,
                                                  id: id,
                                                  date: DateTime.now(),
                                                  companyid: value.companyid,
                                                  company: value.company,
                                                );

                                                await value.db
                                                    .collection(
                                                      'return_reasons',
                                                    )
                                                    .doc(id)
                                                    .set(newMode.toMap());

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      widget.docId != null
                                                          ? "Reason updated successfully"
                                                          : "reason saved successfully",
                                                    ),
                                                  ),
                                                );

                                                _formKey.currentState!.reset();
                                                _nameController.clear();
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Error: ${e.toString()}",
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                setState(
                                                  () => _isLoading = false,
                                                );
                                              }
                                            },
                                      child: _isLoading
                                          ? SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                              ),
                                            )
                                          : Text(
                                              widget.docId != null
                                                  ? "Update"
                                                  : "Register",
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        side: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      icon: Icon(
                                        Icons.view_list,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                      label: Text(
                                        "View",
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReturnReasonLists(),
                                          ),
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
          ),
        );
      },
    );
  }
}
