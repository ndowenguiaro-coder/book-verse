class BookItem {
  final int id;
  final String title;
  final String author;
  final String? genre;
  final String? category;
  final String? coverUrl;
  final String? audioUrl;
  final int viewCount;
  final bool isDownloaded;
  final bool isFavorite;

  BookItem({
    required this.id,
    required this.title,
    required this.author,
    this.genre,
    this.category,
    this.coverUrl,
    this.audioUrl,
    this.viewCount = 0,
    this.isDownloaded = false,
    this.isFavorite = false,
  });

  factory BookItem.fromJson(Map<String, dynamic> json, {String baseUrl = ''}) {
    final cover = json['cover_filename'] as String?;
    return BookItem(
      id: json['id'] as int,
      title: json['title'] as String,
      author: json['author'] as String,
      genre: json['genre'] != null ? json['genre']['name'] as String : null,
      category: json['category'] != null ? json['category']['name'] as String : null,
      coverUrl: cover != null ? '$baseUrl/static/covers/$cover' : null,
      audioUrl: json['audio_url'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
    );
  }

  BookItem copyWith({bool? isDownloaded, bool? isFavorite}) {
    return BookItem(
      id: id,
      title: title,
      author: author,
      genre: genre,
      category: category,
      coverUrl: coverUrl,
      audioUrl: audioUrl,
      viewCount: viewCount,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
