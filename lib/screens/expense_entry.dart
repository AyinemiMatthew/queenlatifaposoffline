import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/expense_entry_model.dart';
import 'package:kologsoft/models/sub_account_model.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:provider/provider.dart';

class ExpenseEntry extends StatefulWidget {
  final ExpenseEntryModel? expense;

  const ExpenseEntry({super.key, this.expense});

  @override
  State<ExpenseEntry> createState() => _ExpenseEntryState();
}

class _ExpenseEntryState extends State<ExpenseEntry> {
  final _formKey = GlobalKey<FormState>();
  final _expenseNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _receiptNumberController = TextEditingController();
  final _vendorNameController = TextEditingController();

  String _selectedCategory = '';
  String _selectedPaymentMethod = '';
  //SubAccountModel? _selectedAccount;
  DateTime _expenseDate = DateTime.now();
  bool _isSaving = false;
  //List<SubAccountModel> _paymentAccounts = [];
  //Map<String, dynamic>? _selectedAccount;
  String? _selectedAccount;
  List<String> _linkedAccounts = [];
  String method = "";
  List<String> _categories = [];
  bool _isLoadingCategories = false;

  List<String> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  Map<String, List<String>> linkedAccounts = {};

  // ---- Branch options (new) ----
  List<String> _branches = [];
  Map<String, String> _branchIds = {}; // branch name -> branch doc id
  String? _selectedBranch;

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _fieldColor =>
      _isLightTheme ? Colors.white : const Color(0xFF182232);
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : Colors.white12;

  // ---- Design tokens (new, UI only) ----
  Color get _pageColor =>
      _isLightTheme ? const Color(0xFFF3F5F8) : const Color(0xFF101624);
  Color get _cardColor =>
      _isLightTheme ? Colors.white : const Color(0xFF182232);
  Color get _primaryButtonColor => _isLightTheme
      ? const Color(0xFF1F2430)
      : Theme.of(context).colorScheme.primary;
  Color get _primaryButtonTextColor =>
      _isLightTheme ? Colors.white : Theme.of(context).colorScheme.onPrimary;
  static const double _fieldRadius = 16;

  bool _isLoadingLinkedAccounts = false;

  @override
  void initState() {
    super.initState();
    //_loadPaymentAccounts();
    if (widget.expense != null) {
      _populateForm();
    }
    _fetchExpenseCategories();
    _fetchPaymentMethods();
    _fetchBranches();
  }

  void _fetchBranches() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db
          .collection('branches')
          .where('companyid', isEqualTo: datafeed.companyid)
          .get();

      final names = <String>[];
      final ids = <String, String>{};
      for (var doc in snapshot.docs) {
        final name = doc.data()['branchname']?.toString() ?? '';
        if (name.isNotEmpty) {
          names.add(name);
          ids[name] = doc.id;
        }
      }
      final current = datafeed.branch?.toString() ?? '';
      if (current.isNotEmpty && !names.contains(current)) {
        names.insert(0, current);
        ids[current] = datafeed.branchid?.toString() ?? '';
      }

      setState(() {
        _branches = names;
        _branchIds = ids;
        _selectedBranch = current.isNotEmpty ? current : null;
      });
    } catch (e) {
      debugPrint("Error loading branches: $e");
    }
  }

  void _fetchPaymentMethods() async {
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db
          .collection('paymentaccounts')
          .where('companyId', isEqualTo: datafeed.companyid)
          .get();

      for (var doc in snapshot.docs) {
        final map = doc.data();

        method = map['paymentMethod']?.toString() ?? '';
        final accounts = List<String>.from(map['linkedAccounts'] ?? []);

        if (method.isNotEmpty) {
          linkedAccounts[method] = accounts;
        }
      }
      print(linkedAccounts.keys);
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        //_isLoadingPaymentMethods = false;
      });
    }
  }

  void _fetchLinkedAccounts(String paymentMethod) async {
    setState(() {
      _isLoadingLinkedAccounts = true;
      _linkedAccounts = [];
      _selectedAccount = null;
    });

    try {
      final datafeed = context.read<Datafeed>();

      final snapshot = await datafeed.db
          .collection('paymentaccounts')
          .where('paymentMethod', isEqualTo: paymentMethod)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final linked = data['linkedAccounts'];

        if (linked is List) {
          _linkedAccounts = linked.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint("Error loading linked accounts: $e");
    }

    setState(() {
      _isLoadingLinkedAccounts = false;
    });
  }

  void _fetchExpenseCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final datafeed = context.read<Datafeed>();
      final snapshot = await datafeed.db
          .collection('accounts')
          .where('companyId', isEqualTo: datafeed.companyid)
          .where('accountClass', isEqualTo: 'Expense')
          .get();
      final names = snapshot.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _categories = names;
      });
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() {
        // _isLoadingCategories = false;
      });
    }
  }

  void _populateForm() {
    final expense = widget.expense!;
    _expenseNameController.text = expense.expenseName;
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _receiptNumberController.text = expense.receiptNumber;
    _vendorNameController.text = expense.vendorName;
    _selectedCategory = expense.category;
    _selectedPaymentMethod = expense.paymentMethod;
    _expenseDate = expense.expenseDate ?? DateTime.now();
  }
  Widget _buildSearchableDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return FormField<String>(
      // Rebuilds when the value changes (including the reset after saving)
      key: ValueKey(value),
      initialValue: value,
      validator: (v) {
        if (v == null || v.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
      builder: (state) {
        return InkWell(
          borderRadius: BorderRadius.circular(_fieldRadius),
          onTap: () async {
            final picked = await _showSearchSheet(label, items, value);
            if (picked != null) {
              state.didChange(picked);
              onChanged(picked);
            }
          },
          child: InputDecorator(
            isEmpty: value == null || value.isEmpty,
            decoration: _fieldDecoration(label: label, icon: icon).copyWith(
              errorText: state.errorText,
              suffixIcon: Icon(Icons.arrow_drop_down, color: _mutedColor),
            ),
            child: Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textColor, fontSize: 16),
            ),
          ),
        );
      },
    );
  }

  /// Bottom sheet with a search box that filters the list as you type.
  Future<String?> _showSearchSheet(
      String title,
      List<String> items,
      String? current,
      ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = items
                .where((e) => e.toLowerCase().contains(query.toLowerCase()))
                .toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(color: _textColor),
                        decoration: _fieldDecoration(
                          label: 'Search $title',
                          icon: Icons.search,
                        ),
                        onChanged: (v) => setSheetState(() => query = v),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Text(
                          'No matches found',
                          style: TextStyle(color: _mutedColor),
                        ),
                      )
                          : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final selected = item == current;
                          return ListTile(
                            title: Text(
                              item,
                              style: TextStyle(color: _textColor),
                            ),
                            trailing: selected
                                ? Icon(
                              Icons.check,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary,
                            )
                                : null,
                            onTap: () =>
                                Navigator.pop(sheetContext, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  @override
  void dispose() {
    _expenseNameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _receiptNumberController.dispose();
    _vendorNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(surface: _fieldColor, onSurface: _textColor),
          dialogBackgroundColor: _fieldColor,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _expenseDate) {
      setState(() {
        _expenseDate = picked;
      });
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPaymentMethod.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final datafeed = context.read<Datafeed>();
      final expenseName = _expenseNameController.text.trim();
      final companyid = datafeed.companyid;
      final companyName = datafeed.company;
      final branchid = datafeed.branchid;
      final staffPosition = datafeed.staffPosition;
      final branchName = datafeed.branch;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final expensebranchName = _selectedBranch ?? datafeed.branch;
      final expensebranchId = _selectedBranch != null
          ? (_branchIds[_selectedBranch] ?? datafeed.branchid)
          : datafeed.branchid;
      final docId = '${companyid}_${expenseName}_${staffPosition}_$timestamp'
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');

      final expense = ExpenseEntryModel(
        id: widget.expense?.id ?? docId,
        expenseName: expenseName,
        expensebranchId: expensebranchId,
        expensebranchName: expensebranchName,
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCategory,
        subAccountId: _selectedAccount!,
        subAccountName: _selectedAccount!,
        paymentMethod: _selectedPaymentMethod,
        receiptNumber: _receiptNumberController.text.trim(),
        vendorName: _vendorNameController.text.trim(),
        staff: datafeed.staff,
        companyid: companyid,
        companyName: companyName,
        branchId: branchid,
        branchName: branchName,
        companyemail: datafeed.companyemail,
        expenseDate: _expenseDate,
        date: widget.expense?.date ?? DateTime.now(),
        updatedat: DateTime.now(),
        createdAtTimestamp: widget.expense == null
            ? timestamp
            : widget.expense!.createdAtTimestamp,
      );

      // Save to Firestore
      if (widget.expense == null) {
        // Check for duplicate first
        final existingDoc = await datafeed.db
            .collection('expenses')
            .doc(docId)
            .get();

        if (existingDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense already exists'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          print(datafeed.staffPosition);

          setState(() {
            _isSaving = false;
          });

          return;
        }

        // Save only if it doesn't exist
        await datafeed.db
            .collection('expenses')
            .doc(docId)
            .set(expense.toMap());
      } else {
        // Existing expense: update by id
        await datafeed.db
            .collection('expenses')
            .doc(expense.id)
            .update(expense.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.expense == null
                  ? 'Expense saved successfully'
                  : 'Expense updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _expenseNameController.clear();
        _descriptionController.clear();
        _amountController.clear();
        _receiptNumberController.clear();
        _vendorNameController.clear();
        setState(() {
          _selectedAccount = null;
          _selectedCategory = '';
          _selectedPaymentMethod = '';
          _expenseDate = DateTime.now();
        });
        //Navigator.pop(context, expense);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        title: Text(widget.expense == null ? 'New Expenses' : 'Edit Expense'),
        backgroundColor: _isLightTheme
            ? Colors.white
            : Theme.of(context).colorScheme.surface,
        foregroundColor: _textColor,
        elevation: 2,
        actions: [
          if (_isSaving)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveExpense,
              tooltip: 'Save Expense',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        _isLightTheme ? 0.12 : 0.35,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card header
                    Text(
                      'Expense Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide the expense, payment and branch information for this entry.',
                      style: TextStyle(fontSize: 14, color: _mutedColor),
                    ),
                    const SizedBox(height: 20),

                    // Expense Name | Amount
                    _fieldRow(
                      _buildTextField(
                        controller: _expenseNameController,
                        label: 'Expense Name',
                        hint: 'e.g., Office Supplies Purchase',
                        icon: Icons.receipt_long,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter expense name';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: _amountController,
                        label: 'Amount',
                        hint: '0.00',
                        icon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                                (oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text) ? newValue : oldValue,
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter amount';
                          }
                          final text = value.trim();
                          if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(text)) {
                            return 'Enter a valid number, e.g. 25 or 25.50';
                          }
                          final amount = double.tryParse(text);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category (full width)
                    _buildSearchableDropdown(
                      label: 'Category',
                      value: _selectedCategory.isEmpty ? null : _selectedCategory,
                      items: _categories,
                      icon: Icons.category,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Payment Method | Branch
                    _fieldRow(
                      _buildDropdown(
                        label: 'Payment Method',
                        value: _selectedPaymentMethod.isEmpty
                            ? null
                            : _selectedPaymentMethod,
                        items: linkedAccounts.keys.toList(),
                        icon: Icons.payment,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentMethod = value ?? '';
                            _selectedAccount = null;
                          });
                          if (value != null && value.isNotEmpty) {
                            setState(() {
                              _linkedAccounts = linkedAccounts[value]!.toList();
                            });
                            // _fetchLinkedAccounts(value);
                          } else {
                            setState(() {
                              _linkedAccounts = linkedAccounts[value]!.toList();
                            });
                          }
                        },
                      ),
                      _buildBranchDropdown(),
                    ),
                    const SizedBox(height: 16),

                    // Payment Account (full width)
                    _buildLinkedAccountDropdown(),
                    const SizedBox(height: 16),

                    // Vendor Name | Receipt Number
                    _fieldRow(
                      _buildTextField(
                        controller: _vendorNameController,
                        label: 'Vendor/Supplier Name',
                        hint: 'Optional',
                        icon: Icons.business,
                        required: false,
                      ),
                      _buildTextField(
                        controller: _receiptNumberController,
                        label: 'Receipt/Invoice Number',
                        hint: 'Optional',
                        icon: Icons.receipt,
                        required: false,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description (full width)
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Add any additional notes',
                      icon: Icons.notes,
                      maxLines: 4,
                      required: false,
                    ),
                    const SizedBox(height: 16),

                    // Expense Date
                    _buildDateField(
                      label: 'Expense Date',
                      date: _expenseDate,
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 24),

                    // Buttons: wide primary + compact outlined
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveExpense,
                            icon: _isSaving
                                ? const SizedBox.shrink()
                                : Icon(
                              Icons.arrow_forward,
                              color: _primaryButtonTextColor,
                            ),
                            label: _isSaving
                                ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primaryButtonTextColor,
                              ),
                            )
                                : Text(
                              widget.expense == null
                                  ? 'Save Expense'
                                  : 'Update Expense',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _primaryButtonTextColor,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryButtonColor,
                              foregroundColor: _primaryButtonTextColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  _fieldRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.expenseview);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textColor,
                            side: BorderSide(color: _borderColor),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 28,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_fieldRadius),
                            ),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
    );
  }

  /// Two fields side by side on wide screens, stacked on narrow ones.
  Widget _fieldRow(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  /// Shared pill-style decoration used by every field.
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _mutedColor),
      labelStyle: TextStyle(color: _mutedColor),
      hintStyle: TextStyle(color: _mutedColor),
      filled: true,
      fillColor: _fieldColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: border(_borderColor),
      enabledBorder: border(_borderColor),
      disabledBorder: border(_borderColor),
      focusedBorder: border(Theme.of(context).colorScheme.primary, 2),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(Colors.red, 2),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: _textColor),
      decoration: _fieldDecoration(label: label, icon: icon, hint: hint),
      validator: required ? validator : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(_fieldRadius),
      decoration: _fieldDecoration(label: label, icon: icon),
      dropdownColor: _fieldColor,
      style: TextStyle(color: _textColor),
      items: items.map((String item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
    );
  }

  // NEW: Branch dropdown
  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: _branches.contains(_selectedBranch) ? _selectedBranch : null,
      isExpanded: true,
      borderRadius: BorderRadius.circular(_fieldRadius),
      decoration: _fieldDecoration(
        label: 'Branch',
        icon: Icons.location_city,
      ),
      dropdownColor: _fieldColor,
      style: TextStyle(color: _textColor),
      items: _branches.map((String branch) {
        return DropdownMenuItem<String>(value: branch, child: Text(branch));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedBranch = value;
        });
      },
    );
  }

  Widget _buildLinkedAccountDropdown() {
    final hasMethod = _selectedPaymentMethod.isNotEmpty;
    final hasAccounts = _linkedAccounts.isNotEmpty;

    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      isExpanded: true,
      borderRadius: BorderRadius.circular(_fieldRadius),
      disabledHint: Text(
        !hasMethod ? 'Select payment method first' : 'No accounts available',
        style: TextStyle(color: _mutedColor),
      ),
      decoration: _fieldDecoration(
        label: 'Payment Account',
        icon: Icons.account_balance_outlined,
      ),
      dropdownColor: _fieldColor,
      style: TextStyle(color: _textColor),

      onChanged: (!hasMethod || !hasAccounts)
          ? null
          : (value) {
        setState(() {
          _selectedAccount = value;
        });
      },

      items: _linkedAccounts.map((accountName) {
        return DropdownMenuItem<String>(
          value: accountName,
          child: Text(accountName),
        );
      }).toList(),

      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a payment account';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_fieldRadius),
      child: InputDecorator(
        decoration: _fieldDecoration(label: label, icon: Icons.calendar_today),
        child: Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: TextStyle(color: _textColor, fontSize: 16),
        ),
      ),
    );
  }
}