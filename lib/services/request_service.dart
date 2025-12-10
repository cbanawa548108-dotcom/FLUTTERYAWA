import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request.dart';

class RequestService {
  static final supabase = Supabase.instance.client;

  /// Borrow a book
  /// Each user can borrow only 1 active book at a time
  static Future<void> borrowBook(String bookId) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Check if user already has a book (pending or approved)
    final existingRequests = await supabase
        .from('requests')
        .select()
        .eq('user_id', user.id)
        .in_('status', ['pending', 'approved']); // active requests

    if ((existingRequests as List).isNotEmpty) {
      throw Exception('You can only borrow 1 book at a time.');
    }

    final borrowDate = DateTime.now();
    final returnDate = borrowDate.add(const Duration(days: 3));

    await supabase.from('requests').insert({
      'user_id': user.id,
      'book_id': bookId,
      'borrow_date': borrowDate.toIso8601String(),
      'return_date': returnDate.toIso8601String(),
      'status': 'pending',
      'fine': 0,
    });
  }

  /// Get all requests (admin view)
  static Future<List<Request>> getAllRequests() async {
    final response = await supabase
        .from('requests')
        .select('*, books(title, author, image_url)')
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => Request.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Get requests for a specific user
  static Future<List<Request>> getUserRequests(String userId) async {
    final response = await supabase
        .from('requests')
        .select('*, books(title, author, image_url)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    return data.map((e) => Request.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Approve a borrow request
  static Future<void> approveRequest(String requestId, String bookId) async {
    await supabase
        .from('requests')
        .update({'status': 'approved'})
        .eq('id', requestId);

    final bookData = await supabase
        .from('books')
        .select()
        .eq('id', bookId)
        .single();

    final currentStock = bookData['available_stock'] as int;
    if (currentStock > 0) {
      await supabase
          .from('books')
          .update({'available_stock': currentStock - 1})
          .eq('id', bookId);
    } else {
      throw Exception('No stock available');
    }
  }

  /// Reject a borrow request
  static Future<void> rejectRequest(String requestId) async {
    await supabase
        .from('requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  /// Mark a book as returned
  static Future<void> returnBook(String requestId, String bookId) async {
    await supabase
        .from('requests')
        .update({'status': 'returned'})
        .eq('id', requestId);

    final bookData = await supabase
        .from('books')
        .select()
        .eq('id', bookId)
        .single();

    final currentStock = bookData['available_stock'] as int;
    await supabase
        .from('books')
        .update({'available_stock': currentStock + 1})
        .eq('id', bookId);
  }
}
