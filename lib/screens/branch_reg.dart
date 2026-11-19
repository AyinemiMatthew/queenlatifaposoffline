import 'package:flutter/material.dart';
import 'package:kologsoft/models/branch.dart';
import 'package:kologsoft/models/debtors.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:provider/provider.dart';

import '../providers/routes.dart';
import 'branch_view.dart';

class BranchRegistration extends StatefulWidget {
  final BranchModel? branch;
  const BranchRegistration({super.key, this.branch});

  @override
  State<BranchRegistration> createState() => _BranchRegistrationState();
}

class _BranchRegistrationState extends State<BranchRegistration> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _branchnameController = TextEditingController();
  final TextEditingController _branchcontactController =
      TextEditingController();
  final TextEditingController _branchAddressController =
      TextEditingController();
  bool _isSaving = false;
  String? _selectedBranchType;
  final List<String> _branchTypes = [
    'Sales Point',
    'Sales Branch',
    'Warehouse',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.branch != null) {
      _branchnameController.text = widget.branch!.branchname;
      _branchcontactController.text = widget.branch!.branchcontact;
      _branchAddressController.text = widget.branch!.address;
      _selectedBranchType = _branchTypes.firstWhere(
        (type) => type.toLowerCase() == widget.branch!.branchtype.toLowerCase(),
        orElse: () => _branchTypes.first,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Datafeed>(
      builder: (BuildContext context, Datafeed value, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final foregroundColor = isDark ? Colors.white : Colors.black87;
        final secondaryForegroundColor = isDark
            ? Colors.white70
            : Colors.black54;
        final fieldFillColor = isDark ? const Color(0xFF22304A) : Colors.white;
        final borderColor = isDark ? Colors.white24 : Colors.black26;

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF101A23)
              : Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.branch != null ? "EDIT BRANCH" : "BRANCH REGISTRATION",
            ),
            backgroundColor: isDark
                ? const Color(0xFF0D1A26)
                : Theme.of(context).colorScheme.surface,
            foregroundColor: foregroundColor,
            elevation: 2,
            actions: [
              IconButton(
                tooltip: "View",
                icon: const Icon(Icons.view_list),
                onPressed: () {
                  Navigator.pushNamed(context,Routes.branchview,);
                },

              ),
              const SizedBox(width: 8),

            ],

          ),
          // floatingActionButton: FloatingActionButton(
          //   backgroundColor: const Color(0xFF415A77),
          //   child: const Icon(Icons.add),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const BranchView()),
          //     );
          //   },
          // ),
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
                        color: isDark
                            ? const Color(0xFF182232)
                            : Theme.of(context).colorScheme.surface,
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
                                controller: _branchnameController,
                                style: TextStyle(color: foregroundColor),
                                decoration: InputDecoration(
                                  labelText: 'Branch Name',
                                  labelStyle: TextStyle(
                                    color: secondaryForegroundColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  fillColor: fieldFillColor,
                                  filled: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter branch name'
                                    : null,
                              ),

                              const SizedBox(height: 14),

                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value:
                                    _branchTypes.contains(_selectedBranchType)
                                    ? _selectedBranchType
                                    : null,
                                dropdownColor: fieldFillColor,
                                style: TextStyle(color: foregroundColor),
                                decoration: InputDecoration(
                                  labelText: 'Branch Type',
                                  labelStyle: TextStyle(
                                    color: secondaryForegroundColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  fillColor: fieldFillColor,
                                  filled: true,
                                ),
                                items: _branchTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBranchType = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select branch type'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _selectedBranchType == 'Sales Point'
                                      ? 'Sales point sells from warehouses with stock balance.'
                                      : _selectedBranchType == 'Sales Branch'
                                      ? 'Sales branch holds its own stock.'
                                      : _selectedBranchType == 'Warehouse'
                                      ? 'Warehouse keeps stock to be transferred or requested by branches.'
                                      : 'Select a branch type to see details.',
                                  style: TextStyle(
                                    color: secondaryForegroundColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              SizedBox(height: 14),
                              TextFormField(
                                controller: _branchcontactController,
                                style: TextStyle(color: foregroundColor),
                                decoration: InputDecoration(
                                  labelText: 'Branch Contact',
                                  labelStyle: TextStyle(
                                    color: secondaryForegroundColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  fillColor: fieldFillColor,
                                  filled: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter branch contact'
                                    : null,
                              ),
                              SizedBox(height: 14),
                              TextFormField(
                                controller: _branchAddressController,
                                style: TextStyle(color: foregroundColor),
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'Branch Address',
                                  labelStyle: TextStyle(
                                    color: secondaryForegroundColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.blue,
                                    ),
                                  ),
                                  fillColor: fieldFillColor,
                                  filled: true,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter branch address'
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
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      onPressed: _isSaving
                                          ? null
                                          : () async {
                                              if (!_formKey.currentState!
                                                  .validate())
                                                return;

                                              setState(() {
                                                _isSaving = true;
                                              });

                                              try {
                                                final branch = BranchModel(
                                                  id: widget.branch?.id ?? '',
                                                  branchname:
                                                      _branchnameController.text
                                                          .trim(),
                                                  branchtype:
                                                      _selectedBranchType!,
                                                  address:
                                                      _branchAddressController
                                                          .text
                                                          .trim(),
                                                  branchcontact:
                                                      _branchcontactController
                                                          .text
                                                          .trim(),
                                                  staff: value.staff,
                                                  companyid: value.companyid,
                                                  companyemail:
                                                      value.companyemail,
                                                  date: widget.branch == null
                                                      ? DateTime.now()
                                                      : widget.branch?.date,
                                                  updatedat: DateTime.now(),
                                                  deletedat:
                                                      widget.branch?.deletedat,
                                                  updatedby:
                                                      widget
                                                          .branch
                                                          ?.updatedby ??
                                                      '',
                                                  deletedby:
                                                      widget
                                                          .branch
                                                          ?.deletedby ??
                                                      '',
                                                );

                                                await value.addOrUpdateBranch(
                                                  branch,
                                                );

                                                if (!mounted) return;

                                                if (widget.branch != null) {
                                                  Navigator.pop(context, true);
                                                  return;
                                                }

                                                _branchnameController.clear();
                                                _branchcontactController
                                                    .clear();
                                                _branchAddressController
                                                    .clear();
                                                setState(
                                                  () => _selectedBranchType =
                                                      null,
                                                );

                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Branch saved successfully',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
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
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isSaving = false;
                                                  });
                                                }
                                              }
                                            },
                                      child: _isSaving
                                          ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              widget.branch != null
                                                  ? "Update"
                                                  : "Add",
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                  // SizedBox(
                                  //   width: 200,
                                  //   child: OutlinedButton.icon(
                                  //     style: OutlinedButton.styleFrom(
                                  //       side: BorderSide(
                                  //         color: secondaryForegroundColor,
                                  //       ),
                                  //       padding: const EdgeInsets.symmetric(
                                  //         vertical: 16,
                                  //       ),
                                  //       shape: RoundedRectangleBorder(
                                  //         borderRadius: BorderRadius.circular(
                                  //           14,
                                  //         ),
                                  //       ),
                                  //     ),
                                  //     icon: Icon(
                                  //       Icons.view_list,
                                  //       color: secondaryForegroundColor,
                                  //     ),
                                  //     label: Text(
                                  //       "View",
                                  //       style: TextStyle(
                                  //         color: secondaryForegroundColor,
                                  //       ),
                                  //     ),
                                  //     onPressed: () {
                                  //       Navigator.pushNamed(
                                  //         context,
                                  //         Routes.branchview,
                                  //       );
                                  //     },
                                  //   ),
                                  // ),
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
