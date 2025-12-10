class Book {
  final String id;
  final String title;
  final String author;
  final int availableStock;
  final String? imageUrl; // add this

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.availableStock,
    this.imageUrl,
  });

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      availableStock: map['available_stock'] ?? 0,
      imageUrl: map['image_url'], // read the image URL
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'available_stock': availableStock,
      'image_url': imageUrl, // include it in toMap
    };
  }
}
