import 'package:flutter/material.dart';
import '../services/book_service.dart';
import '../services/request_service.dart';
import '../services/auth_service.dart';
import '../models/book.dart';
import '../models/request.dart';
import 'login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;
  bool _hasActiveBook = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkActiveBook();
  }

  Future<void> _loadUserProfile() async {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      setState(() {
        _userProfile = response;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _checkActiveBook() async {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) return;

    try {
      final requests = await RequestService.getUserRequests(userId);
      setState(() {
        _hasActiveBook = requests.any(
          (r) => r.status == 'pending' || r.status == 'approved',
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Styled profile card
          if (_userProfile != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade300,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: _userProfile!['avatar_url'] != null
                        ? NetworkImage(_userProfile!['avatar_url'])
                        : null,
                    child: _userProfile!['avatar_url'] == null
                        ? const Icon(Icons.person, size: 35)
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userProfile!['full_name'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _userProfile!['email'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _selectedIndex == 0
                ? _buildBooksTab()
                : _buildMyRequestsTab(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Books'),
          BottomNavigationBarItem(
            icon: Icon(Icons.request_page),
            label: 'My Requests',
          ),
        ],
      ),
    );
  }

  Widget _buildBooksTab() {
    return FutureBuilder<List<Book>>(
      future: BookService.getAllBooks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final books = snapshot.data ?? [];
        if (books.isEmpty) {
          return const Center(child: Text('No books available'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _checkActiveBook();
            setState(() {});
          },
          child: ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: book.imageUrl != null
                        ? NetworkImage(book.imageUrl!)
                        : null,
                    child: book.imageUrl == null
                        ? const Icon(Icons.book)
                        : null,
                  ),
                  title: Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'by ${book.author}\nAvailable: ${book.availableStock}',
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: (book.availableStock > 0 && !_hasActiveBook)
                        ? () async {
                            try {
                              await RequestService.borrowBook(book.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Borrow request sent!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                await _checkActiveBook();
                                setState(() {});
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        : null,
                    child: const Text('Borrow'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMyRequestsTab() {
    final userId = AuthService.getCurrentUserId();
    if (userId == null) return const Center(child: Text('Please log in'));

    return FutureBuilder<List<Request>>(
      future: RequestService.getUserRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(child: Text('No requests yet'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _checkActiveBook();
            setState(() {});
          },
          child: ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              Color statusColor;
              switch (request.status) {
                case 'pending':
                  statusColor = Colors.orange;
                  break;
                case 'approved':
                  statusColor = Colors.green;
                  break;
                case 'rejected':
                  statusColor = Colors.red;
                  break;
                case 'returned':
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor,
                    child: const Icon(Icons.request_page, color: Colors.white),
                  ),
                  title: Text(
                    request.bookTitle ?? 'Book ID: ${request.bookId}',
                  ),
                  subtitle: Text(
                    '${request.bookAuthor ?? ''}\nStatus: ${request.status.toUpperCase()}\nBorrow: ${request.borrowDate.toString().split(' ')[0]}\nReturn: ${request.returnDate.toString().split(' ')[0]}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
