import 'package:flutter/material.dart';
import '../services/request_service.dart';
import '../models/request.dart';

class AdminRequestApprovalScreen extends StatefulWidget {
  const AdminRequestApprovalScreen({super.key});

  @override
  State<AdminRequestApprovalScreen> createState() =>
      _AdminRequestApprovalScreenState();
}

class _AdminRequestApprovalScreenState
    extends State<AdminRequestApprovalScreen> {
  List<Request> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  void loadRequests() async {
    setState(() => isLoading = true);
    try {
      final data = await RequestService.getAllRequests();
      setState(() {
        requests = data.where((r) => r.status == 'pending').toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void approveRequest(String id, String bookId) async {
    try {
      await RequestService.approveRequest(id, bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved'),
            backgroundColor: Colors.green,
          ),
        );
        loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void rejectRequest(String id) async {
    try {
      await RequestService.rejectRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Approve Requests")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const Center(child: Text('No pending requests'))
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final r = requests[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: r.bookImageUrl != null
                          ? NetworkImage(r.bookImageUrl!)
                          : null,
                      child: r.bookImageUrl == null
                          ? const Icon(Icons.menu_book)
                          : null,
                    ),
                    title: Text(r.bookTitle ?? 'Book ID: ${r.bookId}'),
                    subtitle: Text(
                      'Author: ${r.bookAuthor ?? 'Unknown'}\n'
                      'User ID: ${r.userId}\n'
                      'Borrow: ${r.borrowDate.toString().split(' ')[0]}\n'
                      'Return: ${r.returnDate.toString().split(' ')[0]}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => approveRequest(r.id, r.bookId),
                          icon: const Icon(Icons.check, color: Colors.green),
                        ),
                        IconButton(
                          onPressed: () => rejectRequest(r.id),
                          icon: const Icon(Icons.close, color: Colors.red),
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
