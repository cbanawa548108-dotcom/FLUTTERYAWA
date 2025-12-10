import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book.dart';

class BookService {
  static final supabase = Supabase.instance.client;
  static const bucket =
      'books'; // Make sure this bucket exists in Supabase Storage

  /// Fetch all books
  static Future<List<Book>> getAllBooks() async {
    try {
      final data = await supabase
          .from('books')
          .select()
          .order('title', ascending: true);
      return (data as List).map((e) => Book.fromMap(e)).toList();
    } catch (e) {
      throw Exception('Failed to load books: $e');
    }
  }

  /// Add a new book
  static Future<void> addBook(
    String title,
    String author,
    int stock, [
    String? imageUrl,
  ]) async {
    try {
      await supabase.from('books').insert({
        'title': title,
        'author': author,
        'total_stock': stock,
        'available_stock': stock,
        'image_url': imageUrl,
      });
    } catch (e) {
      throw Exception('Failed to add book: $e');
    }
  }

  /// Upload book image (web)
  static Future<String> uploadBookImageWeb(
    String fileName,
    Uint8List bytes,
  ) async {
    try {
      final storageRes = await supabase.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true),
          );

      // Get the public URL
      final url = supabase.storage.from(bucket).getPublicUrl(fileName);
      if (url.isEmpty) throw Exception('Failed to get public URL');
      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Delete a book
  static Future<void> deleteBook(String bookId) async {
    try {
      await supabase.from('books').delete().eq('id', bookId);
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  /// Update book stock
  static Future<void> updateBookStock(String bookId, int availableStock) async {
    try {
      await supabase
          .from('books')
          .update({'available_stock': availableStock})
          .eq('id', bookId);
    } catch (e) {
      throw Exception('Failed to update book stock: $e');
    }
  }
}
