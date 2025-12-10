import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/book_service.dart';

class AdminAddBookScreen extends StatefulWidget {
  const AdminAddBookScreen({super.key});

  @override
  State<AdminAddBookScreen> createState() => _AdminAddBookScreenState();
}

class _AdminAddBookScreenState extends State<AdminAddBookScreen> {
  final titleController = TextEditingController();
  final authorController = TextEditingController();
  final stockController = TextEditingController();

  Uint8List? pickedImage;
  String? pickedFileName;

  bool isLoading = false;

  @override
  void dispose() {
    titleController.dispose();
    authorController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        pickedImage = result.files.single.bytes;
        pickedFileName = result.files.single.name;
      });
    }
  }

  Future<void> addBook() async {
    final title = titleController.text.trim();
    final author = authorController.text.trim();
    final stock = int.tryParse(stockController.text.trim()) ?? 0;

    if (title.isEmpty || author.isEmpty || stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields correctly")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String? imageUrl;
      if (pickedImage != null && pickedFileName != null) {
        imageUrl = await BookService.uploadBookImageWeb(
          pickedFileName!,
          pickedImage!,
        );
      }

      await BookService.addBook(title, author, stock, imageUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Book added successfully"),
          backgroundColor: Colors.green,
        ),
      );

      titleController.clear();
      authorController.clear();
      stockController.clear();
      setState(() {
        pickedImage = null;
        pickedFileName = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Book")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: pickedImage != null
                    ? Image.memory(pickedImage!, fit: BoxFit.cover)
                    : const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Book Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                labelText: "Author",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(
                labelText: "Stock",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : addBook,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Book", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
