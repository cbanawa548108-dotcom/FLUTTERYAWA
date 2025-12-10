import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDamageTransactionScreen extends StatefulWidget {
  const AdminDamageTransactionScreen({super.key});

  @override
  State<AdminDamageTransactionScreen> createState() =>
      _AdminDamageTransactionScreenState();
}

class _AdminDamageTransactionScreenState
    extends State<AdminDamageTransactionScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> damageTransactions = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadDamageTransactions();
  }

  Future<void> loadDamageTransactions() async {
    setState(() => isLoading = true);
    try {
      // Fetch only returned books
      final response = await supabase
          .from('requests')
          .select(
            'id, user_id, book_id, status, borrow_date, return_date, fine, fine_paid, payment_mode, users(full_name,email), books(title, author, image_url)',
          )
          .eq('status', 'returned');

      final list = List<Map<String, dynamic>>.from(response);

      setState(() {
        damageTransactions = list;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading damage transactions: $e')),
        );
      }
    }
  }

  void addDamageFine(
    Map<String, dynamic> transaction,
    double fineAmount,
  ) async {
    try {
      await supabase
          .from('requests')
          .update({'fine': fineAmount, 'fine_paid': 'pending'})
          .eq('id', transaction['id']);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Damage fine ₱$fineAmount added')));
      loadDamageTransactions();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add fine: $e')));
    }
  }

  void markFinePaid(
    Map<String, dynamic> transaction,
    String paymentMode,
  ) async {
    try {
      await supabase
          .from('requests')
          .update({'fine_paid': 'paid', 'payment_mode': paymentMode})
          .eq('id', transaction['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fine marked as paid via $paymentMode')),
      );
      loadDamageTransactions();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark fine paid: $e')));
    }
  }

  void showAddFineDialog(Map<String, dynamic> transaction) {
    double fineAmount = 500;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Damage Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Book: ${transaction['books']['title']}'),
            Text('User: ${transaction['users']['full_name']}'),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: fineAmount.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fine Amount'),
              onChanged: (val) {
                fineAmount = double.tryParse(val) ?? 500;
              },
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
              addDamageFine(transaction, fineAmount);
              Navigator.pop(context);
            },
            child: const Text('Add Fine'),
          ),
        ],
      ),
    );
  }

  void showMarkPaidDialog(Map<String, dynamic> transaction) {
    String paymentMode = 'Cash';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark Fine as Paid'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Book: ${transaction['books']['title']}'),
            Text('User: ${transaction['users']['full_name']}'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: paymentMode,
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
              ],
              onChanged: (val) {
                if (val != null) paymentMode = val;
              },
              decoration: const InputDecoration(labelText: 'Payment Mode'),
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
              markFinePaid(transaction, paymentMode);
              Navigator.pop(context);
            },
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingFines = damageTransactions
        .where(
          (t) =>
              (t['fine_paid'] ?? 'pending') == 'pending' &&
              (t['fine'] ?? 0) > 0,
        )
        .toList();
    final paidFines = damageTransactions
        .where((t) => (t['fine_paid'] ?? 'pending') == 'paid')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Damage Fines'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Pending Fines'),
              Tab(text: 'Paid Fines'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: loadDamageTransactions,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  buildFineList(pendingFines, true),
                  buildFineList(paidFines, false),
                ],
              ),
      ),
    );
  }

  Widget buildFineList(List<Map<String, dynamic>> list, bool isPending) {
    if (list.isEmpty) {
      return Center(
        child: Text(isPending ? 'No pending fines' : 'No paid fines'),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final t = list[index];
        final fine = t['fine'] ?? 0;
        final fineStatus = t['fine_paid'] ?? 'pending';
        final paymentMode = t['payment_mode'] ?? '-';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: fineStatus == 'paid' ? Colors.green : Colors.red,
              child: Icon(
                fineStatus == 'paid' ? Icons.check : Icons.warning,
                color: Colors.white,
              ),
            ),
            title: Text(t['books']['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${t['users']['full_name']}'),
                Text('Fine: ₱$fine'),
                Text('Payment Status: $fineStatus'),
                if (fineStatus == 'paid') Text('Mode: $paymentMode'),
              ],
            ),
            trailing: fineStatus == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => showAddFineDialog(t),
                        child: const Text('Add Fine'),
                      ),
                      const SizedBox(width: 5),
                      ElevatedButton(
                        onPressed: () => showMarkPaidDialog(t),
                        child: const Text('Mark Paid'),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
