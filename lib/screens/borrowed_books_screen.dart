import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BorrowedBooksScreen extends StatefulWidget {
  const BorrowedBooksScreen({super.key});

  @override
  State<BorrowedBooksScreen> createState() => _BorrowedBooksScreenState();
}

class _BorrowedBooksScreenState extends State<BorrowedBooksScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> borrowedBooks = [];
  List<Map<String, dynamic>> returnedBooks = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    loadBooks();
  }

  Future<void> loadBooks() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('requests')
          .select(
            'id, borrow_date, return_date, status, fine, fine_paid, users(id,full_name,email), books(title, author, image_url)',
          )
          .order('borrow_date', ascending: false)
          .execute();

      final data = List<Map<String, dynamic>>.from(response.data as List);

      borrowedBooks = data.where((r) => r['status'] != 'returned').toList();
      returnedBooks = data.where((r) => r['status'] == 'returned').toList();

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading books: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show the "Is the book damaged?" dialog
  void showReturnDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Return Book'),
        content: const Text('Is the book damaged?'),
        actions: [
          // No → return directly
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase
                  .from('requests')
                  .update({
                    'status': 'returned',
                    'return_date': DateTime.now().toIso8601String(),
                    'fine': 0,
                    'fine_paid': 'none',
                    'payment_mode': null,
                  })
                  .eq('id', request['id'])
                  .execute();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Book returned successfully'),
                  backgroundColor: Colors.green,
                ),
              );

              loadBooks();
            },
            child: const Text('No'),
          ),
          // Yes → create payment in Admin Transactions
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final fineAmount = 500;

              await supabase.from('payments').insert({
                'user_id': request['users']['id'],
                'request_id': request['id'],
                'amount': fineAmount,
                'paid': false,
              }).execute();

              await supabase
                  .from('requests')
                  .update({
                    'status': 'damaged',
                    'fine': fineAmount,
                    'fine_paid': 'pending',
                  })
                  .eq('id', request['id'])
                  .execute();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Book marked as damaged. Payment of ₱$fineAmount added to Admin Transactions.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );

              loadBooks();
            },
            child: const Text('Yes, damaged'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> list, {
    bool showReturnButton = false,
  }) {
    if (list.isEmpty) return const Center(child: Text('No books to display'));

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, index) {
        final r = list[index];
        final user = r['users'];
        final book = r['books'];

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: book['image_url'] != null
                  ? NetworkImage(book['image_url'])
                  : null,
              child: book['image_url'] == null ? const Icon(Icons.book) : null,
            ),
            title: Text(book['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Author: ${book['author']}'),
                Text('Borrowed by: ${user['full_name']}'),
                Text('Email: ${user['email']}'),
                Text('Borrowed on: ${r['borrow_date']}'),
                Text('Return Date: ${r['return_date'] ?? "Not returned"}'),
                Text('Status: ${r['status']}'),
                if ((r['fine'] ?? 0) > 0)
                  Text('Fine: ₱${r['fine']} - ${r['fine_paid'] ?? 'pending'}'),
              ],
            ),
            trailing: showReturnButton
                ? ElevatedButton(
                    onPressed: () => showReturnDialog(r),
                    child: const Text('Return'),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowed Books'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Borrowed'),
            Tab(text: 'Returned'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(borrowedBooks, showReturnButton: true),
                _buildList(returnedBooks),
              ],
            ),
    );
  }
}
