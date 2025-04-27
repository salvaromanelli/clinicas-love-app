import 'package:flutter/material.dart';
import 'utils/adaptive_sizing.dart';
import 'i18n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/supabase.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/analytics_service.dart';

// Clase para representar artículos externos
class Article {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String articleUrl;
  final bool featured;
  final String? category;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.articleUrl,
    this.featured = false,
    this.category,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      articleUrl: json['article_url'] ?? '',
      featured: json['featured'] ?? false,
      category: json['category'],
    );
  }
}


class EducacionContenidoPage extends StatefulWidget {
  const EducacionContenidoPage({super.key});

  @override
  State<EducacionContenidoPage> createState() => _EducacionContenidoPageState();
}

class _EducacionContenidoPageState extends State<EducacionContenidoPage> {
  List<Article> _articles = [];
  bool _isLoading = true;
  String? _errorMessage;

  final DateTime _pageEnteredTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    AnalyticsService().logPageView('education_content');
    _loadArticles();
  }
  
  // Método para cargar artículos desde Supabase
Future<void> _loadArticles() async {
  final startTime = DateTime.now();
  
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });
  
  try {
    final data = await SupabaseService().client
        .from('articles')
        .select()
        .order('order_index', ascending: true);
    
    setState(() {
      _articles = (data as List).map((item) {
        final article = Article.fromJson(item);
        
        if (!_isValidImageUrl(article.imageUrl)) {
          debugPrint('URL de imagen inválida para artículo "${article.title}": ${article.imageUrl}');
        }
        
        return article;
      }).toList();
      _isLoading = false;
    });
    
    // Registrar éxito en carga de artículos
    AnalyticsService().logInteraction('articles_loaded', {
      'article_count': _articles.length,
      'featured_count': _articles.where((a) => a.featured).length,
      'load_time_ms': DateTime.now().difference(startTime).inMilliseconds,
      'categories': _getCategoriesCounts(),
    });
  } catch (e) {
    setState(() {
      _errorMessage = 'Error cargando artículos: $e';
      _isLoading = false;
    });
    
    // Registrar error en carga
    AnalyticsService().logInteraction('articles_load_error', {
      'error_message': e.toString(),
      'load_time_ms': DateTime.now().difference(startTime).inMilliseconds,
    });
    
    debugPrint('Error cargando artículos: $e');
  }
}

@override
void dispose() {
  AnalyticsService().logInteraction('education_content_exited', {
    'time_spent_seconds': DateTime.now().difference(_pageEnteredTime).inSeconds,
    'articles_count': _articles.length,
  });
  super.dispose();
}

// Método auxiliar para contar categorías de artículos
Map<String, int> _getCategoriesCounts() {
  Map<String, int> counts = {};
  for (var article in _articles) {
    final category = article.category ?? 'uncategorized';
    counts[category] = (counts[category] ?? 0) + 1;
  }
  return counts;
}
  
  Future<void> _refreshArticles() async {
    // Registrar inicio de actualización
    final startTime = DateTime.now();
    final previousCount = _articles.length;
    
    AnalyticsService().logInteraction('refresh_articles_started', {
      'previous_article_count': previousCount,
    });
    
    await _loadArticles();
    
    // Registrar resultado de actualización
    AnalyticsService().logInteraction('refresh_articles_completed', {
      'new_article_count': _articles.length,
      'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
      'success': _errorMessage == null,
      'delta_count': _articles.length - previousCount,
    });
    
    // Mostrar mensaje de confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contenido actualizado'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Método para abrir URLs externas
  Future<void> _launchUrl(BuildContext context, String urlString, {
    String? articleId,
    String? articleTitle,
    bool isFeatured = false,
    String? category
  }) async {
    // Registrar evento de apertura de artículo
    AnalyticsService().logInteraction('article_opened', {
      'article_id': articleId ?? 'unknown',
      'article_title': articleTitle ?? 'unknown',
      'is_featured': isFeatured,
      'category': category ?? 'unknown',
      'article_url': urlString,
    });
    
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          // Registrar error al abrir
          AnalyticsService().logInteraction('article_open_error', {
            'article_id': articleId ?? 'unknown',
            'error': 'could_not_launch_url',
            'url': urlString,
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir el enlace')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Registrar error de URL inválida
        AnalyticsService().logInteraction('article_open_error', {
          'article_id': articleId ?? 'unknown',
          'error': 'invalid_url',
          'url': urlString,
          'error_message': e.toString(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL inválida: $e')),
        );
      }
    }
  }

  // Método para verificar y corregir URLs de imágenes
bool _isValidImageUrl(String url) {
  if (url.isEmpty) return false;
  
  // Verificar si la URL tiene un formato válido
  Uri? uri;
  try {
    uri = Uri.parse(url);
  } catch (e) {
    return false;
  }
  
  // Verificar que sea http o https
  return uri.scheme == 'http' || uri.scheme == 'https';
}

// Método para obtener una URL de fallback si la original no es válida
String _getImageUrl(String originalUrl) {
  if (_isValidImageUrl(originalUrl)) {
    return originalUrl;
  } else {
    debugPrint('URL de imagen no válida: $originalUrl, usando imagen de respaldo');
    // Una imagen de respaldo en caso de URLs inválidas
    return 'https://via.placeholder.com/800x600/242830/FFFFFF?text=Imagen+no+disponible';
  }
}

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize para dimensiones responsivas
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Obtener traducciones si están disponibles
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera con botón de retroceso y logo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Botón de retroceso
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: AdaptiveSize.getIconSize(context, baseSize: 20),
                  ),
                  padding: EdgeInsets.all(AdaptiveSize.w(8)),
                  constraints: BoxConstraints(
                    minWidth: AdaptiveSize.w(40),
                    minHeight: AdaptiveSize.h(40),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                
                // Logo en el centro
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AdaptiveSize.h(isSmallScreen ? 12 : 16)),
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: AdaptiveSize.h(isSmallScreen ? 60 : 80),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Espacio vacío para equilibrar el diseño
                SizedBox(width: AdaptiveSize.w(48)),
              ],
            ),
            
            // Encabezado de sección con botón de refrescar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AdaptiveSize.w(isSmallScreen ? 16 : 24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.get('aesthetics'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      // Botón de refrescar
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: AdaptiveSize.getIconSize(context, baseSize: 22),
                        ),
                        constraints: BoxConstraints(
                          minWidth: AdaptiveSize.w(40),
                          minHeight: AdaptiveSize.h(40),
                        ),
                        onPressed: _refreshArticles,
                        tooltip: 'Actualizar contenido',
                      ),

                    ],
                  ),
                ],
              ),
            ),
            
            // Contenido principal
            Expanded(
              child: _isLoading 
                ? _buildLoadingView()
                : _errorMessage != null 
                  ? _buildErrorView()
                  : _articles.isEmpty 
                    ? _buildEmptyView(localizations)
                    : _buildContentView(context, isSmallScreen, localizations),
            ),
          ],
        ),
      ),
    );
  }
  
  // Vista de carga
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: AdaptiveSize.h(16)),
          Text(
            'Cargando artículos...',
            style: TextStyle(
              color: Colors.white,
              fontSize: AdaptiveSize.sp(16),
            ),
          ),
        ],
      ),
    );
  }
  
  // Vista de error
  Widget _buildErrorView() {
  
  AnalyticsService().logInteraction('articles_error_view', {
    'error_message': _errorMessage,
  });
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AdaptiveSize.w(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[300],
              size: AdaptiveSize.getIconSize(context, baseSize: 48),
            ),
            SizedBox(height: AdaptiveSize.h(16)),
            Text(
              _errorMessage ?? 'Ha ocurrido un error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: AdaptiveSize.sp(16),
              ),
            ),
            SizedBox(height: AdaptiveSize.h(24)),
            ElevatedButton.icon(
              onPressed: _loadArticles,
              icon: Icon(Icons.refresh),
              label: Text('Intentar de nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF293038),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: AdaptiveSize.w(16),
                  vertical: AdaptiveSize.h(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Vista vacía (sin artículos)
  Widget _buildEmptyView(AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AdaptiveSize.w(24)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              color: Colors.grey[400],
              size: AdaptiveSize.getIconSize(context, baseSize: 48),
            ),
            SizedBox(height: AdaptiveSize.h(16)),
            Text(
              localizations.get('no_articles') ?? 'No hay artículos disponibles',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: AdaptiveSize.sp(16),
              ),
            ),
            SizedBox(height: AdaptiveSize.h(8)),
            Text(
              localizations.get('check_back_later') ?? 'Vuelve a revisar más tarde',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: AdaptiveSize.sp(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Vista principal de contenido
  Widget _buildContentView(BuildContext context, bool isSmallScreen, AppLocalizations localizations) {
    // Encontrar el artículo destacado (o usar el primero)
    final featuredArticle = _articles.firstWhere(
      (article) => article.featured, 
      orElse: () => _articles.first
    );
    
    // Resto de artículos
    final otherArticles = _articles.where((article) => article.id != featuredArticle.id).toList();
    
    AnalyticsService().logInteraction('articles_impression', {
      'total_articles': _articles.length,
      'featured_article_id': featuredArticle.id,
      'featured_article_title': featuredArticle.title,
      'other_articles_count': otherArticles.length,
    });

    return RefreshIndicator(
      onRefresh: _refreshArticles,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AdaptiveSize.w(isSmallScreen ? 16 : 24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.get('learn_about_aesthetics') ?? 'Aprende sobre estética',
              style: TextStyle(
                color: Colors.white,
                fontSize: AdaptiveSize.sp(isSmallScreen ? 22 : 24),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AdaptiveSize.h(isSmallScreen ? 16 : 24)),
            
            // Artículo destacado
            _buildFeaturedArticleCard(
              context, 
              isSmallScreen, 
              featuredArticle,
              localizations
            ),
            
            // Artículos adicionales
            if (otherArticles.isNotEmpty) SizedBox(height: AdaptiveSize.h(24)),
            
            // Mostrar el resto de artículos
            for (final article in otherArticles)
              Column(
                children: [
                  _buildArticleCard(
                    context,
                    isSmallScreen,
                    article.title,
                    article.description,
                    article.imageUrl,
                    article.articleUrl,
                    localizations,
                    article.id,
                    article.category, 
                  ),
                  SizedBox(height: AdaptiveSize.h(20)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  // Tarjeta de artículo destacado
  Widget _buildFeaturedArticleCard(
    BuildContext context, 
    bool isSmallScreen, 
    Article article,
    AppLocalizations localizations
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C2126),
        borderRadius: BorderRadius.circular(AdaptiveSize.w(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: AdaptiveSize.w(8),
            offset: Offset(0, AdaptiveSize.h(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen de portada con shimmer durante la carga
          Stack(
            children: [
              // Shimmer placeholder
              Container(
                height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                color: const Color(0xFF242830),
              ),
              // Imagen real
              CachedNetworkImage(
                imageUrl: _getImageUrl(article.imageUrl),
                height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                  color: const Color(0xFF242830),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      strokeWidth: AdaptiveSize.w(2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  debugPrint('Error cargando imagen: $url, error: $error');
                  return Container(
                    height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                    color: Colors.grey[800],
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: AdaptiveSize.getIconSize(context, baseSize: 40),
                            color: Colors.white70,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Error al cargar imagen',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: AdaptiveSize.sp(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          // Contenido de texto
          Padding(
            padding: EdgeInsets.all(AdaptiveSize.w(isSmallScreen ? 16 : 24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 12 : 16)),
                Text(
                  article.description,
                  style: TextStyle(
                    color: const Color(0xFF9DABB8),
                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 20 : 24)),
                
                // Botón de acción modificado para abrir URL
                ElevatedButton(
                  onPressed: () => _launchUrl(
                    context, 
                    article.articleUrl,
                    articleId: article.id,
                    articleTitle: article.title,
                    isFeatured: true,
                    category: article.category
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF293038),
                    padding: EdgeInsets.symmetric(
                      vertical: AdaptiveSize.h(isSmallScreen ? 12 : 16),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdaptiveSize.w(8)),
                    ),
                    elevation: 0,
                  ),
                  child: Center(
                    child: Text(
                      localizations.get('view_now') ?? 'Ver ahora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget para construir tarjetas de artículos adicionales
  Widget _buildArticleCard(
    BuildContext context, 
    bool isSmallScreen, 
    String title, 
    String description, 
    String imageUrl,
    String articleUrl, 
    AppLocalizations localizations,
    String articleId,
    String? category 

  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C2126),
        borderRadius: BorderRadius.circular(AdaptiveSize.w(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: AdaptiveSize.w(8),
            offset: Offset(0, AdaptiveSize.h(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagen del artículo con timestamp para evitar caché
          Stack(
            children: [
              // Shimmer placeholder
              Container(
                height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                color: const Color(0xFF242830),
              ),
              // Imagen real
              CachedNetworkImage(
                imageUrl: _getImageUrl(imageUrl),
                height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                  color: const Color(0xFF242830),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      strokeWidth: AdaptiveSize.w(2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  debugPrint('Error cargando imagen: $url, error: $error');
                  return Container(
                    height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                    color: Colors.grey[800],
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: AdaptiveSize.getIconSize(context, baseSize: 30),
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          
          // Contenido de texto
          Padding(
            padding: EdgeInsets.all(AdaptiveSize.w(isSmallScreen ? 16 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AdaptiveSize.sp(isSmallScreen ? 15 : 17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 8 : 12)),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xFF9DABB8),
                    fontSize: AdaptiveSize.sp(isSmallScreen ? 13 : 15),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 12 : 16)),
                
                // Botón de leer más
                TextButton(
                  onPressed: () => _launchUrl(
                    context, 
                    articleUrl,
                    articleId: articleId, 
                    articleTitle: title,
                    isFeatured: false,
                    category: category
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1980E6),
                    padding: EdgeInsets.symmetric(
                      horizontal: AdaptiveSize.w(isSmallScreen ? 12 : 16),
                      vertical: AdaptiveSize.h(isSmallScreen ? 6 : 8),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdaptiveSize.w(6)),
                    ),
                  ),
                  child: Text(
                    localizations.get('read_more') ?? 'Leer más',
                    style: TextStyle(
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 13 : 15),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}