import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kologsoft/models/journalentrymodel.dart';
import 'package:kologsoft/providers/Datafeed.dart';
import 'package:kologsoft/providers/routes.dart';
import 'package:kologsoft/screens/journal_entries.dart';
import 'package:provider/provider.dart';

class JournalEntryView extends StatefulWidget {
  const JournalEntryView({super.key});

  @override
  State<JournalEntryView> createState() => _JournalEntryViewState();
}

class _JournalEntryViewState extends State<JournalEntryView> {
  late Stream<QuerySnapshot> _journalsStream;
  bool _isDeleting = false;

  bool get _isLightTheme => Theme.of(context).brightness == Brightness.light;
  Color get _textColor => Theme.of(context).colorScheme.onSurface;
  Color get _mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _surfaceColor =>
      _isLightTheme ? Colors.white : const Color(0xFF182232);
  Color get _borderColor =>
      _isLightTheme ? Colors.grey.shade300 : Colors.white12;

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    final datafeed = context.read<Datafeed>();
    _journalsStream = datafeed.db
        .collection('journal')
        .where('companyId', isEqualTo: datafeed.companyid)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _deleteJournal(String journalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceColor,
        title: Text(
          'Delete Journal Entry',
          style: TextStyle(color: _textColor),
        ),
        content: Text(
          'Are you sure you want to delete this journal entry? This action cannot be undone.',
          style: TextStyle(color: _mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final datafeed = context.read<Datafeed>();
      await datafeed.db.collection('journal').doc(journalId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _editJournal(JournalEntryModel journal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => JournalEntries(journal: journal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isLightTheme ? Colors.white : const Color(0xFF101A23),
      appBar: AppBar(
        title: const Text("JOURNAL ENTRIES"),
        backgroundColor: _isLightTheme ? Colors.white : const Color(0xFF0D1A26),
        foregroundColor: _textColor,
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JournalEntries(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('New Entry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _journalsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: _textColor),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 80, color: _mutedColor),
                  const SizedBox(height: 16),
                  Text(
                    'No journal entries found',
                    style: TextStyle(color: _mutedColor, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JournalEntries(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            );
          }

          final journals = snapshot.data!.docs;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [_buildJournalsList(journals)]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJournalsList(List<QueryDocumentSnapshot> journals) {
    return Column(
      children: journals.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final journal = JournalEntryModel.fromJson(data);

        return Card(
          color: _surfaceColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with ID and date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entry ID: ${journal.id}',
                            style: TextStyle(color: _mutedColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            journal.date != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(journal.date!)
                                : 'N/A',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        'GHS ${journal.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: _isLightTheme
                          ? Colors.green.shade50
                          : Colors.green.withOpacity(0.3),
                      side: BorderSide(color: Colors.green.shade700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: _borderColor, height: 1),
                const SizedBox(height: 12),

                // Account information
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Debit Account',
                        value: journal.debitAccount,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Credit Account',
                        value: journal.creditAccount,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Branch and staff information
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Branch',
                        value: journal.branchName,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Staff',
                        value: journal.staff,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Time period information
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoColumn(label: 'Day', value: journal.day),
                    ),
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Month',
                        value: journal.month,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoColumn(
                        label: 'Year',
                        value: journal.year,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: _borderColor, height: 1),
                const SizedBox(height: 12),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _editJournal(journal),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isDeleting
                          ? null
                          : () => _deleteJournal(journal.id),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        disabledBackgroundColor: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoColumn({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _mutedColor, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value.isEmpty ? 'N/A' : value,
          style: TextStyle(
            color: _textColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
