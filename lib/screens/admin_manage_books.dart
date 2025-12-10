import 'package:flutter/material.dart';
import '../services/book_service.dart';
import '../models/book.dart';

class AdminManageBooksScreen extends StatefulWidget {
  const AdminManageBooksScreen({super.key});

  @override
  State<AdminManageBooksScreen> createState() => _AdminManageBooksScreenState();
}

class _AdminManageBooksScreenState extends State<AdminManageBooksScreen> {
  late Future<List<Book>> booksFuture;

  @override
  void initState() {
    super.initState();
    booksFuture = BookService.getAllBooks();
  }

  void refreshBooks() {
    setState(() {
      booksFuture = BookService.getAllBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Books")),
      body: FutureBuilder<List<Book>>(
        future: booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final books = snapshot.data ?? [];

          if (books.isEmpty) {
            return const Center(child: Text("No books found."));
          }

          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (_, i) {
              final book = books[i];
              return ListTile(
                leading: book.imageUrl != null && book.imageUrl!.isNotEmpty
                    ? Image.network(
                        book.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.menu_book, size: 35),
                title: Text(book.title),
                subtitle: Text(
                  "Author: ${book.author}\nAvailable: ${book.availableStock}",
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    bool confirm = await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Delete Book"),
                        content: Text(
                          "Are you sure you want to delete '${book.title}'?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete"),
                          ),
                        ],
                      ),
                    );

                    if (confirm) {
                      await BookService.deleteBook(book.id);
                      refreshBooks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${book.title} deleted.")),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
