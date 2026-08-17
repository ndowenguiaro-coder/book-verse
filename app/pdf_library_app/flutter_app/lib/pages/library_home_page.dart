import 'package:flutter/material.dart';
import '../models/book_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../core/animations/book_animations.dart';
import '../core/animations/micro_interactions.dart';
import '../core/animations/page_transitions.dart';
import 'login_page.dart';
import 'pdf_reader_tts_page.dart';

class LibraryHomePage extends StatefulWidget {
  const LibraryHomePage({Key? key, required this.baseUrl, required this.authService}) : super(key: key);

  final String baseUrl;
  final AuthService authService;

  @override
  State<LibraryHomePage> createState() => _LibraryHomePageState();
}

class _LibraryHomePageState extends State<LibraryHomePage> {
  late final ApiService _api = ApiService(baseUrl: widget.baseUrl, authService: widget.authService);
  final LocalStorageService _local = LocalStorageService();

  // Genres et catégories chargés dynamiquement depuis l'API : ils sont
  // personnalisables (créés/supprimés par l'utilisateur), donc plus jamais
  // codés en dur comme dans la première maquette.
  List<Map<String, dynamic>> _genres = [
    {'id': null, 'name': 'Tous'}
  ];
  List<Map<String, dynamic>> _categories = [
    {'id': null, 'name': 'Toutes'}
  ];

  // Sections calculées (tri serveur ou état local), pas des Category en base.
  static const _smartSections = ['Nouveautés', 'Les plus lus', 'Téléchargés', 'Favoris'];

  dynamic _selectedGenreId;
  dynamic _selectedCategoryId;
  String? _selectedSmartSection;
  String _searchQuery = '';

  List<BookItem> _books = [];
  Set<int> _downloadedIds = {};
  Set<int> _favoriteIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _api.fetchGenres(),
        _api.fetchCategories(),
        _local.listDownloadedIds(),
        _api.fetchFavoriteIds(),
      ]);
      setState(() {
        _genres = [
          {'id': null, 'name': 'Tous'},
          ...results[0] as List<Map<String, dynamic>>,
        ];
        _categories = [
          {'id': null, 'name': 'Toutes'},
          ...results[1] as List<Map<String, dynamic>>,
        ];
        _downloadedIds = Set<int>.from(results[2] as List<int>);
        _favoriteIds = Set<int>.from(results[3] as List<int>);
      });
      await _refreshBooks();
    } catch (e) {
      setState(() {
        _error = 'Impossible de joindre le serveur : $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshBooks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? sortBy;
      if (_selectedSmartSection == 'Nouveautés') sortBy = 'newest';
      if (_selectedSmartSection == 'Les plus lus') sortBy = 'popular';

      List<BookItem> books = await _api.fetchBooks(
        genreId: _selectedGenreId,
        categoryId: _selectedCategoryId,
        search: _searchQuery,
        sortBy: sortBy,
      );

      if (_selectedSmartSection == 'Favoris') {
        books = books.where((b) => _favoriteIds.contains(b.id)).toList();
      } else if (_selectedSmartSection == 'Téléchargés') {
        books = books.where((b) => _downloadedIds.contains(b.id)).toList();
      }

      setState(() {
        _books = books
            .map((b) => b.copyWith(
                  isDownloaded: _downloadedIds.contains(b.id),
                  isFavorite: _favoriteIds.contains(b.id),
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement des livres : $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(BookItem book) async {
    if (!await widget.authService.isLoggedIn()) {
      _goToLogin();
      return;
    }
    final isFav = _favoriteIds.contains(book.id);
    setState(() {
      isFav ? _favoriteIds.remove(book.id) : _favoriteIds.add(book.id);
    });
    try {
      if (isFav) {
        await _api.removeFavorite(book.id);
      } else {
        await _api.addFavorite(book.id);
      }
      if (_selectedSmartSection == 'Favoris') await _refreshBooks();
    } catch (_) {
      // Réseau indisponible : on annule le changement optimiste.
      setState(() {
        isFav ? _favoriteIds.add(book.id) : _favoriteIds.remove(book.id);
      });
    }
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginPage(baseUrl: widget.baseUrl, authService: widget.authService),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginPage(baseUrl: widget.baseUrl, authService: widget.authService),
      ),
    );
  }

  void _openBook(BookItem book) {
    Navigator.of(context).push(
      BookVersePageRoute(page: PdfReaderTtsPage(
          baseUrl: widget.baseUrl,
          authService: widget.authService,
          book: book,
          localStorage: _local,
          onOpened: () => _api.registerView(book.id),
        )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ma Bibliothèque', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          FutureBuilder<bool>(
            future: widget.authService.isLoggedIn(),
            builder: (context, snapshot) {
              final loggedIn = snapshot.data ?? false;
              return IconButton(
                icon: Icon(loggedIn ? Icons.logout : Icons.login),
                tooltip: loggedIn ? 'Se déconnecter' : 'Se connecter',
                onPressed: loggedIn ? _logout : _goToLogin,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBooks,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _refreshBooks();
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher par titre ou auteur...',
                    // Bug corrigé : Colors.slateGray n'existe pas dans Flutter.
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterRow(
                title: 'Genres',
                items: _genres,
                selectedId: _selectedGenreId,
                onSelected: (id) {
                  _selectedGenreId = id;
                  _refreshBooks();
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterRow(
                title: 'Catégories',
                items: _categories,
                selectedId: _selectedCategoryId,
                onSelected: (id) {
                  _selectedCategoryId = id;
                  _refreshBooks();
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _smartSections.map((section) {
                    final selected = section == _selectedSmartSection;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(section),
                        selected: selected,
                        onSelected: (_) {
                          _selectedSmartSection = selected ? null : section;
                          _refreshBooks();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              )
            else if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_books.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('Aucun livre ne correspond à votre recherche.')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = _books[index];
                      return _BookCard(
                        book: book,
                        onTap: () => _openBook(book),
                        onFavoriteToggle: () => _toggleFavorite(book),
                      );
                    },
                    childCount: _books.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final dynamic selectedId;
  final ValueChanged<dynamic> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = item['id'] == selectedId;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FilterChip(
                  label: Text(item['name'] as String),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4F46E5),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => onSelected(isSelected ? null : item['id']),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap, required this.onFavoriteToggle});
  final BookItem book;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final cover = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFE2E8F0),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 8))],
        image: book.coverUrl != null ? DecorationImage(image: NetworkImage(book.coverUrl!), fit: BoxFit.cover) : null,
      ),
      child: book.coverUrl == null ? const Center(child: Icon(Icons.menu_book, size: 44, color: Colors.white)) : null,
    );
    return BookTilt(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Hero(tag: 'book-cover-${book.id}', child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: cover)),
          Positioned(top: 7, left: 7, child: Container(decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: FavoriteBurst(active: book.isFavorite, onTap: onFavoriteToggle))),
          if (book.isDownloaded) Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle), child: const Icon(Icons.download_done, size: 15, color: Colors.amber))),
        ]))),
        const SizedBox(height: 9),
        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ]),
    );
  }
}
