import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf_tools;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/book_item.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../core/animations/book_animations.dart';
import '../core/animations/animation_constants.dart';

class PdfReaderTtsPage extends StatefulWidget {
  const PdfReaderTtsPage({
    Key? key,
    required this.baseUrl,
    required this.authService,
    required this.book,
    required this.localStorage,
    this.onOpened,
  }) : super(key: key);

  final String baseUrl;
  final AuthService authService;
  final BookItem book;
  final LocalStorageService localStorage;
  final VoidCallback? onOpened;

  @override
  State<PdfReaderTtsPage> createState() => _PdfReaderTtsPageState();
}

class _PdfReaderTtsPageState extends State<PdfReaderTtsPage> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final FlutterTts _flutterTts = FlutterTts();
  late final ApiService _api = ApiService(baseUrl: widget.baseUrl, authService: widget.authService);
  int? _resumePage; // dernière page lue, récupérée du serveur si connecté

  Uint8List? _pdfBytes;
  pdf_tools.PdfDocument? _textDocument; // parsé une seule fois, pas à chaque page
  bool _isLoading = true;
  bool _isPlaying = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _loadError;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _immersive = false;
  double _pageTurn = 0;
  int _lastPage = 1;

  // Vitesses flutter_tts (0.0 à 1.0) associées à un libellé cohérent.
  // Avant : le menu affichait "0.5x"/"1.0x"/"1.5x"/"2.0x" pour des valeurs
  // (0.3/0.5/0.75/1.0) qui ne correspondaient à aucune de ces vitesses réelles.
  static const List<MapEntry<double, String>> _speedOptions = [
    MapEntry(0.25, '0.5x (Lent)'),
    MapEntry(0.5, '1.0x (Normal)'),
    MapEntry(0.75, '1.5x (Rapide)'),
    MapEntry(1.0, '2.0x (Très rapide)'),
  ];
  double _speechRate = 0.5;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPdf();
    widget.onOpened?.call();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() => setState(() => _isPlaying = true));
    _flutterTts.setCompletionHandler(() => setState(() => _isPlaying = false));
    _flutterTts.setErrorHandler((msg) {
      setState(() => _isPlaying = false);
      _showSnackBar('Erreur de synthèse vocale : $msg');
    });
  }

  /// Charge le PDF depuis le stockage local s'il a déjà été téléchargé
  /// ("Disponibilité en ligne ET hors-ligne" demandée) ; sinon le récupère
  /// depuis le serveur. Le document texte n'est ouvert qu'une seule fois ici,
  /// au lieu d'être reconstruit à chaque appui sur le bouton lecture.
  Future<void> _loadPdf() async {
    try {
      Uint8List? bytes = await widget.localStorage.readBook(widget.book.id);
      final wasAlreadyLocal = bytes != null;
      final results = await Future.wait([
        bytes != null ? Future.value(bytes) : _api.downloadPdfBytes(widget.book.id),
        _api.fetchReadingProgress(widget.book.id),
      ]);
      bytes = results[0] as Uint8List;
      _resumePage = results[1] as int?;

      final document = pdf_tools.PdfDocument(inputBytes: bytes);
      setState(() {
        _pdfBytes = bytes;
        _textDocument = document;
        _isDownloaded = wasAlreadyLocal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Impossible de charger le document : $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadForOffline() async {
    if (_pdfBytes == null || _isDownloaded) return;
    setState(() => _isDownloading = true);
    try {
      await widget.localStorage.saveBook(widget.book.id, _pdfBytes!);
      setState(() {
        _isDownloaded = true;
        _isDownloading = false;
      });
      _showSnackBar('Livre disponible hors-ligne.');
    } catch (e) {
      setState(() => _isDownloading = false);
      _showSnackBar('Échec du téléchargement : $e');
    }
  }

  String _extractTextFromCurrentPage() {
    if (_textDocument == null) return '';
    try {
      final extractor = pdf_tools.PdfTextExtractor(_textDocument!);
      return extractor
          .extractText(startPageIndex: _currentPage - 1, endPageIndex: _currentPage - 1)
          .trim();
    } catch (e) {
      _showSnackBar("Erreur lors de l'extraction du texte : $e");
      return '';
    }
  }

  Future<void> _toggleTts() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
      return;
    }
    final text = _extractTextFromCurrentPage();
    if (text.isEmpty) {
      _showSnackBar('Aucun texte lisible trouvé sur cette page.');
      return;
    }
    await _flutterTts.speak(text);
  }

  void _animatePageTurn(int page) {
    if (!mounted || page == _lastPage) return;
    setState(() => _pageTurn = 1);
    _lastPage = page;
    Future.delayed(const Duration(milliseconds: 280), () { if (mounted) setState(() => _pageTurn = 0); });
  }

  Future<void> _changeSpeechRate(double rate) async {
    setState(() => _speechRate = rate);
    await _flutterTts.setSpeechRate(rate);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _flutterTts.stop();
    _textDocument?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _immersive ? null : AppBar(
        leading: widget.book.coverUrl == null ? null : Padding(padding: const EdgeInsets.all(7), child: Hero(tag: 'book-cover-${widget.book.id}', child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(widget.book.coverUrl!, fit: BoxFit.cover)))),
        title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.fullscreen), tooltip: 'Mode immersif', onPressed: () => setState(() => _immersive = true)),
          if (!_isLoading && _loadError == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '$_currentPage / $_totalPages',
                  // Bug corrigé : "FontWeight: FontWeight.bold" (double
                  // affectation invalide) faisait échouer la compilation.
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: Icon(_isDownloaded ? Icons.download_done : Icons.download_outlined),
            tooltip: _isDownloaded ? 'Déjà disponible hors-ligne' : 'Télécharger pour lecture hors-ligne',
            onPressed: _isDownloading || _isDownloaded ? null : _downloadForOffline,
          ),
        ],
      ),
      body: Stack(children: [
        _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement et préparation du PDF...'),
                ],
              ),
            )
          : _loadError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
              : Stack(
                  children: [
                    SfPdfViewer.memory(
                      _pdfBytes!,
                      controller: _pdfViewerController,
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        setState(() => _totalPages = details.document.pages.count);
                        final resumePage = _resumePage;
                        if (resumePage != null && resumePage > 1 && resumePage <= _totalPages) {
                          _pdfViewerController.jumpToPage(resumePage);
                        }
                      },
                      onPageChanged: (PdfPageChangedDetails details) {
                        setState(() => _currentPage = details.newPageNumber);
                        _animatePageTurn(details.newPageNumber);
                        if (_isPlaying) _flutterTts.stop();
                        // Envoi en tâche de fond ; les échecs réseau sont ignorés,
                        // la progression sera resynchronisée à la prochaine ouverture.
                        _api.saveReadingProgress(widget.book.id, details.newPageNumber);
                      },
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white.withOpacity(0.95),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              FloatingActionButton.small(
                                onPressed: _toggleTts,
                                backgroundColor: _isPlaying ? Colors.red : Colors.indigo,
                                child: Icon(_isPlaying ? Icons.stop : Icons.volume_up, color: Colors.white),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isPlaying ? 'Lecture vocale en cours...' : 'Écouter cette page',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isPlaying ? Colors.indigo : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      _speedOptions.firstWhere((e) => e.key == _speechRate).value,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<double>(
                                icon: const Icon(Icons.speed, color: Colors.indigo),
                                onSelected: _changeSpeechRate,
                                itemBuilder: (context) => _speedOptions
                                    .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        if (_immersive)
          Positioned(top: 18, right: 18, child: SafeArea(child: IconButton.filled(onPressed: () => setState(() => _immersive = false), icon: const Icon(Icons.fullscreen_exit)))),
        if (_pageTurn > 0)
          Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(opacity: _pageTurn, duration: BookVerseMotion.micro, child: Align(alignment: Alignment.centerRight, child: Container(width: 34, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.transparent, Colors.white54]))))))),
      ]),
    );
  }
}
