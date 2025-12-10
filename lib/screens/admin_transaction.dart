import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTransactionScreen extends StatefulWidget {
  const AdminTransactionScreen({super.key});

  @override
  State<AdminTransactionScreen> createState() => _AdminTransactionScreenState();
}

class _AdminTransactionScreenState extends State<AdminTransactionScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadTransactions();
  }

  /// Load all payments including user and book info
  Future<void> loadTransactions() async {
    setState(() => isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select(
            'id, amount, paid, payment_mode, request_id, user_id, '
            'requests(id, status, books(title, author), users(full_name,email))',
          )
          .order('id', ascending: false)
          .execute();

      if (response.error != null) {
        throw response.error!.message;
      }

      setState(() {
        transactions = List<Map<String, dynamic>>.from(response.data as List);
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Process payment and mark request as returned
  Future<void> processPaymentAndReturn(
    Map<String, dynamic> transaction,
    String paymentMode,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Update payment record
      await supabase
          .from('payments')
          .update({'paid': true, 'payment_mode': paymentMode})
          .eq('id', transaction['id'])
          .execute();

      // 2. Update request to returned
      await supabase
          .from('requests')
          .update({
            'status': 'returned',
            'return_date': DateTime.now().toIso8601String(),
            'fine_paid': 'paid',
            'payment_mode': paymentMode,
          })
          .eq('id', transaction['request_id'])
          .execute();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment processed and book returned. Amount: ₱${transaction['amount']}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh list
      await loadTransactions();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show payment dialog
  void showPaymentDialog(Map<String, dynamic> transaction) {
    String selectedMode = 'Cash';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Process Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Book: ${transaction['requests']['books']['title']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('User: ${transaction['requests']['users']['full_name']}'),
              Text('Email: ${transaction['requests']['users']['email']}'),
              Text(
                'Fine Amount: ₱${transaction['amount']}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Payment Mode:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMode,
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedMode = val;
                    });
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                processPaymentAndReturn(transaction, selectedMode);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Process Payment & Return Book'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the list of transactions
  Widget buildTransactionList(List<Map<String, dynamic>> list, bool isPaid) {
    if (list.isEmpty) {
      return Center(child: Text(isPaid ? 'No paid fines' : 'No unpaid fines'));
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, index) {
        final t = list[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPaid ? Colors.green : Colors.red,
              child: Icon(
                isPaid ? Icons.check : Icons.warning,
                color: Colors.white,
              ),
            ),
            title: Text(t['requests']['books']['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${t['requests']['users']['full_name']}'),
                Text('Email: ${t['requests']['users']['email']}'),
                Text('Amount: ₱${t['amount']}'),
                Text('Paid: ${t['paid'] ? "Yes" : "No"}'),
                if (t['paid'] == true)
                  Text('Payment Mode: ${t['payment_mode'] ?? "-"}'),
              ],
            ),
            trailing: !isPaid
                ? ElevatedButton.icon(
                    onPressed: () => showPaymentDialog(t),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text('Pay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidTransactions = transactions
        .where((t) => t['paid'] == true)
        .toList();
    final unpaidTransactions = transactions
        .where((t) => t['paid'] == false)
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payments / Damaged Books'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Unpaid'),
              Tab(text: 'Paid'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadTransactions,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  buildTransactionList(unpaidTransactions, false),
                  buildTransactionList(paidTransactions, true),
                ],
              ),
      ),
    );
  }
}

extension on PostgrestResponse<dynamic> {
  get error => null;
}
