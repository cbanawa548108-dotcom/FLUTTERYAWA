import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'admin_add_book.dart';
import 'admin_request_approval.dart';
import 'admin_transaction.dart';
import 'admin_members.dart';
import 'admin_manage_books.dart';
import 'borrowed_books_screen.dart';
import 'admin_damage_transaction.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int borrowedTodayCount = 0;
  int totalUsers = 0;
  int totalTransactions = 0;
  int overdueBooksCount = 0;
  bool isLoading = true;

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> borrowedTodayList = [];
  List<Map<String, dynamic>> overdueBooksList = [];

  Timer? autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    loadDashboardData();

    // AUTO REFRESH EVERY 5 SECONDS
    autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadDashboardData(refreshLoading: false);
    });
  }

  @override
  void dispose() {
    autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardData({bool refreshLoading = true}) async {
    if (refreshLoading) {
      setState(() => isLoading = true);
    }

    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    try {
      // Borrowed Today (approved only)
      final borrowedResponse = await supabase
          .from('requests')
          .select(
            'id, borrow_date, return_date, status, users(full_name,email), books(id,title, author, image_url)',
          )
          .eq('status', 'approved')
          .gte('borrow_date', todayStr)
          .lte('borrow_date', todayStr)
          .execute();

      borrowedTodayList = (borrowedResponse.data as List)
          .where((r) => r['users'] != null && r['books'] != null)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      borrowedTodayCount = borrowedTodayList.length;

      // Total Users
      final usersResponse = await supabase
          .from('profiles')
          .select('id')
          .execute();
      totalUsers = (usersResponse.data as List).length;

      // Total Transactions (approved only)
      final txResponse = await supabase
          .from('requests')
          .select('id, status')
          .eq('status', 'approved')
          .execute();
      totalTransactions = (txResponse.data as List).length;

      // Overdue Books
      final overdueResponse = await supabase
          .from('requests')
          .select(
            'id, borrow_date, return_date, status, users(full_name,email), books(id,title, author, image_url)',
          )
          .is_('return_date', null)
          .eq('status', 'approved')
          .execute();

      overdueBooksList = [];
      overdueBooksCount = 0;

      for (var r in (overdueResponse.data as List)) {
        final map = Map<String, dynamic>.from(r as Map);
        final borrowDate = DateTime.parse(map['borrow_date']);

        if (DateTime.now().difference(borrowDate).inDays > 3 &&
            map['users'] != null &&
            map['books'] != null) {
          overdueBooksList.add(map);
          overdueBooksCount++;
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
    }
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminManageBooksScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAddBookScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminRequestApprovalScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminTransactionScreen()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminMembersScreen()),
        );
        break;
    }
  }

  void _showOverdueBooksDetails() {
    if (overdueBooksList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No overdue books')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Overdue Books')),
          body: ListView.builder(
            itemCount: overdueBooksList.length,
            itemBuilder: (_, index) {
              final r = overdueBooksList[index];
              final user = r['users'];
              final book = r['books'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: book['image_url'] != null
                        ? NetworkImage(book['image_url'])
                        : null,
                    child: book['image_url'] == null
                        ? const Icon(Icons.book)
                        : null,
                  ),
                  title: Text(book['title']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Author: ${book['author']}'),
                      Text('Borrowed by: ${user['full_name']}'),
                      Text('Email: ${user['email']}'),
                      Text('Borrowed on: ${r['borrow_date']}'),
                      Text(
                        'Return Date: ${r['return_date'] ?? "Not returned"}',
                      ),
                      Text('Status: ${r['status']}'),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () => loadDashboardData(),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  shrinkWrap: true,
                  children: [
                    _buildInfoCard(
                      'Borrowed Today',
                      borrowedTodayCount,
                      Icons.book,
                      Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BorrowedBooksScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInfoCard(
                      'Total Users',
                      totalUsers,
                      Icons.group,
                      Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminMembersScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInfoCard(
                      'Total Transactions',
                      totalTransactions,
                      Icons.receipt_long,
                      Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminTransactionScreen(),
                          ),
                        );
                      },
                    ),
                    _buildInfoCard(
                      'Overdue Books',
                      overdueBooksCount,
                      Icons.warning,
                      Colors.red,
                      onTap: _showOverdueBooksDetails,
                    ),
                    _buildInfoCard(
                      'Damage Fines',
                      0,
                      Icons.money_off,
                      Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AdminDamageTransactionScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onBottomNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Manage Books',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add Book'),
          BottomNavigationBarItem(icon: Icon(Icons.approval), label: 'Approve'),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Members'),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    int count,
    IconData icon,
    Color color, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: color),
              const SizedBox(height: 10),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
