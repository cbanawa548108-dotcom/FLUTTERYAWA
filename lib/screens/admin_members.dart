import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  void loadUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase.from('profiles').select();
      final data = response as List<dynamic>;

      setState(() {
        users = data;
        filteredUsers = data;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  void filterUsers(String query) {
    final filtered = users.where((user) {
      final name = (user['full_name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final q = query.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    setState(() {
      searchQuery = query;
      filteredUsers = filtered;
    });
  }

  void _openUserDetails(dynamic user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Library Members"),
        backgroundColor: Colors.teal,
        elevation: 2,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: filterUsers,
                  ),
                ),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? const Center(
                          child: Text(
                            "No members found",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          itemCount: filteredUsers.length,
                          itemBuilder: (_, i) {
                            final user = filteredUsers[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 3,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                onTap: () => _openUserDetails(user),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.teal[100],
                                  backgroundImage: user['avatar_url'] != null
                                      ? NetworkImage(user['avatar_url'])
                                      : null,
                                  child: user['avatar_url'] == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 28,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  user['full_name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  user['email'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class UserDetailScreen extends StatefulWidget {
  final dynamic user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> borrowedBooks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBorrowedBooks();
  }

  void loadBorrowedBooks() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('requests')
          .select(
            'id, status, borrow_date, return_date, books(title, author, image_url)',
          )
          .eq('user_id', widget.user['id']);
      final data = response as List<dynamic>;

      setState(() {
        borrowedBooks = data;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading borrowed books: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user['full_name'] ?? 'User Detail'),
        backgroundColor: Colors.teal,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : borrowedBooks.isEmpty
          ? const Center(
              child: Text(
                "No borrowed books",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: borrowedBooks.length,
              itemBuilder: (_, i) {
                final r = borrowedBooks[i];
                final book = r['books'];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue[100],
                      backgroundImage: book['image_url'] != null
                          ? NetworkImage(book['image_url'])
                          : null,
                      child: book['image_url'] == null
                          ? const Icon(Icons.book, color: Colors.white)
                          : null,
                    ),
                    title: Text(book['title'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Author: ${book['author'] ?? ""}'),
                        Text('Borrowed on: ${r['borrow_date'] ?? ""}'),
                        Text('Status: ${r['status'] ?? ""}'),
                        Text(
                          'Return Date: ${r['return_date'] ?? "Not returned"}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
