
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kologsoft/models/customerreg_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../widgets/salespagewidgets/snackmsg.dart';
import 'customerlist.dart';

class CustomerRegistration extends StatefulWidget {
  final String? docId;
  final CustomerRegModel? data;
  const CustomerRegistration({super.key, this.docId, this.data});

  @override
  State<CustomerRegistration> createState() => _CustomerRegistrationState();
}

class _CustomerRegistrationState extends State<CustomerRegistration> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _creditlimitController = TextEditingController();
  final TextEditingController _creditbalanceController =
      TextEditingController();
  final TextEditingController _amountpaidController = TextEditingController();

  String? _selectedCustomerType;
  String? _selectedpaymentduration;
  bool _loading = false;

  late List<String> _customerTypes = ['Cash', 'Credit'];
  late List<String> paymentduration = ['Short term', 'Long term'];

  bool get isCreditCustomer => _selectedCustomerType == 'Credit';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = Provider.of<Datafeed>(context, listen: false);
      provider.fetchBranches();
    });

    if (widget.data != null) {
      final customadata = widget.data!;
      _nameController.text = customadata.name;
      _contactController.text = customadata.contact;
      _creditlimitController.text = customadata.creditlimit ?? '0';
      _creditbalanceController.text = customadata.creditBalance ?? '0';
      _amountpaidController.text = customadata.amountpaid ?? '0';

      final customerType = customadata.customertype;
      if (_customerTypes.contains(customerType)) {
        _selectedCustomerType = customerType;
      }

      final paymentDuration = customadata.paymentduration;
      if (paymentduration.contains(paymentDuration)) {
        _selectedpaymentduration = paymentDuration;
      }
    }

    // Safe provider usage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<Datafeed>();
      provider.fetchBranches();

      if (widget.data != null) {
        final branchId = widget.data!.branchid;
        if (branchId != null && branchId.isNotEmpty) {
          provider.selectBranch(branchId);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _creditlimitController.dispose();
    _creditbalanceController.dispose();
    _amountpaidController.dispose();
    super.dispose();
  }
  Widget _buildBranchDropdown(BuildContext context, Datafeed value) {
    final scheme = Theme.of(context).colorScheme;

    InputDecoration decoration({String? hint}) => InputDecoration(
      labelText: 'Branch',
      hintText: hint,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary),
      ),
      fillColor: scheme.surfaceContainerHighest,
      filled: true,
    );

    try {
      // Usable branches: not a warehouse, has an id, no duplicate ids
      final seen = <String>{};
      final branches = value.branches.where((b) {
        final id = (b.id ?? '').toString().trim();
        if (id.isEmpty) return false;
        if (b.branchtype == 'Warehouse') return false;
        return seen.add(id); // false if this id was already added
      }).toList();

      // Nothing to choose from: show a disabled field instead of breaking
      if (branches.isEmpty) {
        return DropdownButtonFormField<String>(
          value: null,
          isExpanded: true,
          decoration: decoration(hint: 'No branch available'),
          items: const [],
          onChanged: null, // disabled
          validator: (_) => 'No branch available. Add a branch first.',
        );
      }

      // Only pass a value that really exists in the items
      final selectedId = value.selectedBranch?.id?.toString();
      final safeValue =
      branches.any((b) => b.id.toString() == selectedId) ? selectedId : null;

      return DropdownButtonFormField<String>(
        value: safeValue,
        dropdownColor: scheme.surfaceContainerHighest,
        style: TextStyle(color: scheme.onSurface),
        isExpanded: true,
        decoration: decoration(),
        items: branches
            .map(
              (branch) => DropdownMenuItem<String>(
            value: branch.id.toString(),
            child: Text(
              (branch.branchname ?? '').toString().isEmpty
                  ? branch.id.toString()
                  : branch.branchname.toString(),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: (val) {
          if (val == null) return;
          try {
            value.selectBranch(val);
          } catch (e, st) {
            debugPrint('selectBranch failed: $e\n$st');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not select that branch.')),
            );
          }
        },
        validator: (val) => val == null ? 'Please select branch' : null,
      );
    } catch (e, st) {
      // Last resort: never let a data problem crash the screen
      debugPrint('Branch dropdown error: $e\n$st');
      return DropdownButtonFormField<String>(
        value: null,
        isExpanded: true,
        decoration: decoration(hint: 'Branches unavailable'),
        items: const [],
        onChanged: null,
        validator: (_) => 'Branches unavailable. Try again later.',
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.docId != null
                  ? "Edit Customer Registration"
                  : "Customer Registration",
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
              padding: const EdgeInsets.all(8.0),
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
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            top: 20,
                            right: 16,
                            bottom: 20,
                          ),
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
                                  labelText: 'Customer Name',
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
                                    ? 'Enter customer name'
                                    : null,
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _contactController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$'),
                                  ),
                                ],
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),

                                decoration: InputDecoration(
                                  labelText: 'Contact',
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
                                    ? 'Enter valid contact'
                                    : null,
                              ),

                              const SizedBox(height: 14),

                              DropdownButtonFormField<String>(
                                value: _selectedCustomerType,

                                isExpanded: true,
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  labelText: 'Customer Type',
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
                                items: _customerTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCustomerType = value;
                                    if (value != 'Credit') {
                                      _creditlimitController.clear();
                                      _selectedpaymentduration = null;
                                    }
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select customer type'
                                    : null,
                              ),
                              SizedBox(height: 14),
                              if (isCreditCustomer) ...[
                                /// CREDIT LIMIT
                                TextFormField(
                                  controller: _creditlimitController,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*$'),
                                    ),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Credit Limit',
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
                                  validator: (value) {
                                    if (!isCreditCustomer) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'Enter valid credit limit';
                                    }
                                    final num? parsed = num.tryParse(value);
                                    if (parsed == null) {
                                      return 'Only numbers are allowed';
                                    }
                                    if (parsed <= 0) {
                                      return 'Credit limit must be greater than 0';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 14),

                                /// PAYMENT DURATION
                                DropdownButtonFormField<String>(
                                  value: _selectedpaymentduration,
                                  dropdownColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  decoration: InputDecoration(
                                    labelText: 'Payment Duration',
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
                                  items: paymentduration.map((type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(type),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(
                                      () => _selectedpaymentduration = value,
                                    );
                                  },
                                  validator: (value) {
                                    if (!isCreditCustomer) return null;
                                    return value == null
                                        ? 'Please select payment duration'
                                        : null;
                                  },
                                ),
                              ],
                              SizedBox(height: 14),
                              _buildBranchDropdown(context, value),
                              // DropdownButtonFormField<String>(
                              //   value: value
                              //       .selectedBranch
                              //       ?.id, // must be one of branch.id
                              //   dropdownColor: Theme.of(
                              //     context,
                              //   ).colorScheme.surfaceContainerHighest,
                              //   style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              //   isExpanded: true,
                              //   decoration: InputDecoration(
                              //     labelText: 'Branch',
                              //     labelStyle: TextStyle(
                              //       color: Theme.of(context).colorScheme.onSurfaceVariant,
                              //     ),
                              //     border: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //     ),
                              //     enabledBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: BorderSide(
                              //         color: Theme.of(context).colorScheme.outline,
                              //       ),
                              //     ),
                              //     focusedBorder: OutlineInputBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //       borderSide: BorderSide(
                              //         color: Theme.of(context).colorScheme.primary,
                              //       ),
                              //     ),
                              //     fillColor: Theme.of(
                              //       context,
                              //     ).colorScheme.surfaceContainerHighest,
                              //     filled: true,
                              //   ),
                              //   items:
                              //   value.branches
                              //       .where((b) => b.branchtype != "Warehouse")
                              //       .map((branch) {
                              //         return DropdownMenuItem<String>(
                              //           value: branch.id,
                              //           child: Text(branch.branchname),
                              //         );
                              //       })
                              //       .toList(),
                              //   onChanged: (val) {
                              //     if (val != null) {
                              //       value.selectBranch(val);
                              //       // call provider method
                              //     }
                              //   },
                              //   validator: (val) =>
                              //       val == null ? 'Please select branch' : null,
                              // ),

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
                                        backgroundColor: const Color(
                                          0xFF415A77,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: _loading
                                          ? null
                                          : () async {
                                              if (!_formKey.currentState!
                                                  .validate())
                                                return;

                                              setState(() => _loading = true);
                                              String name = _nameController.text
                                                  .trim();
                                              String contact =
                                                  _contactController.text
                                                      .trim();
                                              String creditbalance =
                                                  _creditbalanceController.text
                                                      .trim();
                                              String amountpaid =
                                                  _creditbalanceController.text
                                                      .trim();
                                              String customertype =
                                                  _selectedCustomerType!;
                                              String creditlimit =
                                                  isCreditCustomer
                                                  ? _creditlimitController.text
                                                        .trim()
                                                  : '';
                                              String paymentduration =
                                                  isCreditCustomer
                                                  ? _selectedpaymentduration ??
                                                        ''
                                                  : '';
                                              final branchId =
                                                  value.selectedBranch?.id ??
                                                  '';
                                              final branchName =
                                                  value
                                                      .selectedBranch
                                                      ?.branchname ??
                                                  '';

                                              String
                                              docid = value.normalizeAndSanitize(
                                                "${value.companyid}_${contact}",
                                              );

                                              final existingDoc = await value.db
                                                  .collection('customers');

                                              try {
                                                if (widget.docId != null) {
                                                  final existingDocWithSameContact =
                                                      await existingDoc
                                                          .where(
                                                            'contact',
                                                            isEqualTo: contact,
                                                          )
                                                          .where(
                                                            'companyid',
                                                            isEqualTo:
                                                                value.companyid,
                                                          )
                                                          .limit(1)
                                                          .get();
                                                  // Allow if no match found, OR if the only match is the customer being edited
                                                  final cExists =
                                                      existingDocWithSameContact
                                                          .docs
                                                          .isNotEmpty &&
                                                      existingDocWithSameContact
                                                              .docs
                                                              .first
                                                              .id !=
                                                          widget.docId;
                                                  if (cExists) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor:
                                                            Colors.red,
                                                        content: Text(
                                                          "A customer with this contact  already exists",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                    setState(
                                                      () => _loading = false,
                                                    );
                                                    return;
                                                  }
                                                  final id = widget.docId!;
                                                  final newCustomer =
                                                      CustomerRegModel(
                                                        id: id,
                                                        branchname: branchName,
                                                        branchid: branchId,
                                                        name: name,
                                                        contact: contact,
                                                        customertype:
                                                            customertype,
                                                        creditlimit:
                                                            creditlimit,
                                                        paymentduration:
                                                            paymentduration,
                                                        companyid:
                                                            value.companyid,
                                                        creditBalance:
                                                            creditbalance,
                                                        staff: value.staff,
                                                        date: DateTime.now(),
                                                        updatedby: value.staff,
                                                        updatedat:
                                                            DateTime.now(),
                                                        deletedat: null,
                                                        companyname:
                                                            value.company,
                                                      );

                                                  await existingDoc
                                                      .doc(id)
                                                      .set(
                                                        newCustomer.toMap(),
                                                        SetOptions(merge: true),
                                                      );
                                                  _nameController.clear();
                                                  _contactController.clear();
                                                  _creditbalanceController
                                                      .clear();
                                                  setState(
                                                    () =>
                                                        _selectedCustomerType =
                                                            null,
                                                  );
                                                } else {
                                                  final ref = existingDoc
                                                      .doc(docid)
                                                      .get();

                                                  if (ref != null &&
                                                      (await ref).exists) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor:
                                                            Colors.red,
                                                        content: Text(
                                                          "A customer with this contact  already exists",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                    setState(
                                                      () => _loading = false,
                                                    );
                                                    return;
                                                  }
                                                  final newCustomer =
                                                      CustomerRegModel(
                                                        id: docid,
                                                        branchname: branchName,
                                                        branchid: branchId,
                                                        name: name,
                                                        contact: contact,
                                                        customertype:
                                                            customertype,
                                                        creditlimit:
                                                            creditlimit,
                                                        paymentduration:
                                                            paymentduration,
                                                        companyid:
                                                            value.companyid,
                                                        staff: value.staff,
                                                        date: DateTime.now(),
                                                        updatedat: null,
                                                        deletedat: null,
                                                        companyname:
                                                            value.company,
                                                      );

                                                  await existingDoc
                                                      .doc(docid)
                                                      .set(newCustomer.toMap());
                                                  _nameController.clear();
                                                  _contactController.clear();
                                                  setState(
                                                    () =>
                                                        _selectedCustomerType =
                                                            null,
                                                  );
                                                }
                                                snackMsg(
                                                  context,
                                                  widget.docId == null
                                                      ? "Customer Registered Successfully"
                                                      : "Customer Updated Successfully",
                                                  Colors.green,
                                                );
                                                // ScaffoldMessenger.of(context)
                                                //     .showSnackBar(
                                                //   SnackBar(
                                                //     content: Text(widget.docId == null
                                                //         ? "Customer Registered Successfully"
                                                //         : "Customer Updated Successfully"),
                                                //   ),
                                                // );
                                              } catch (e) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.toString()),
                                                  ),
                                                );
                                              }

                                              if (!mounted) return;
                                              setState(() {
                                                _loading = false;
                                                _selectedCustomerType = null;
                                              });
                                            },
                                      child: _loading
                                          ? const CircularProgressIndicator(
                                              color: Colors.white,
                                            )
                                          : Text(
                                              widget.docId == null
                                                  ? "Register"
                                                  : "Update",
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.light
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary
                                                    : Colors.white70,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.white70,
                                        side: BorderSide(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                              : Colors.white70,
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
                                        color: Theme.of(context).brightness ==
                                                Brightness.light
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.white70,
                                      ),
                                      label: Text(
                                        "View",
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.white70,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CustomerListPage(),
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
