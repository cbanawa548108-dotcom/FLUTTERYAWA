class Request {
  final String id;
  final String userId;
  final String bookId;
  final String status; // pending, approved, returned
  final DateTime borrowDate;
  final DateTime returnDate;
  final double fine;
  final String? finePaid; // 'paid' or 'pending'

  // Book info
  final String? bookTitle;
  final String? bookAuthor;
  final String? bookImageUrl;

  Request({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.status,
    required this.borrowDate,
    required this.returnDate,
    required this.fine,
    this.finePaid,
    this.bookTitle,
    this.bookAuthor,
    this.bookImageUrl,
  });

  // Helper getter to know if the book is currently borrowed
  bool get isBorrowed => status != 'returned';

  // Helper getter to know if the book has been returned
  bool get isReturned => status == 'returned';

  factory Request.fromMap(Map<String, dynamic> map) {
    final book = map['books'] as Map<String, dynamic>?;

    return Request(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      bookId: map['book_id'].toString(),
      status: map['status'] ?? 'pending',
      borrowDate: DateTime.parse(map['borrow_date']),
      returnDate: DateTime.parse(map['return_date']),
      fine: (map['fine'] ?? 0).toDouble(),
      finePaid: map['fine_paid']?.toString(),
      bookTitle: book?['title'],
      bookAuthor: book?['author'],
      bookImageUrl: book?['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'status': status,
      'borrow_date': borrowDate.toIso8601String(),
      'return_date': returnDate.toIso8601String(),
      'fine': fine,
      'fine_paid': finePaid,
    };
  }
}
