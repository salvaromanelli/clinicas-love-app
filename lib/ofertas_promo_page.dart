import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class OfertasPromosPage extends StatefulWidget {
  const OfertasPromosPage({super.key});

  @override
  State<OfertasPromosPage> createState() => _OfertasPromosPageState();
}

class _OfertasPromosPageState extends State<OfertasPromosPage> {
  bool _isLoading = true;
  String _currentUrl = 'https://clinicasloveshop.com/66-promociones-del-mes';
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Inicializar el controlador de WebView
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111418))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Actualizar indicador de progreso
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            
            // Ocultar elementos no deseados de la web con JavaScript
            _removeUnnecessaryElements();
          },
          onWebResourceError: (WebResourceError error) {
            print('Error en WebView: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // Permitir navegación dentro del dominio de la clínica
            if (request.url.startsWith('https://clinicasloveshop.com')) {
              return NavigationDecision.navigate;
            }
            // Para enlaces externos, abrirlos en el navegador externo
            return NavigationDecision.navigate; // También se puede usar .prevent
          },
        ),
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  void _removeUnnecessaryElements() {
    // Inyectar CSS para adaptar mejor el sitio web al móvil si es necesario
    _controller.runJavaScript('''
      try {
        // Intentar eliminar elementos que distraigan como banners, publicidad, etc.
        // Esto dependerá de la estructura del sitio web
        const elementsToHide = [
          '.cookie-banner',
          '#newsletter-popup',
          '.mobile-nav',
          '.promo-bar',
          // Ajusta según la estructura del sitio
        ];
        
        elementsToHide.forEach(selector => {
          const elements = document.querySelectorAll(selector);
          elements.forEach(el => el.style.display = 'none');
        });
        
        // Ajustar estilos si es necesario
        const styleElement = document.createElement('style');
        styleElement.textContent = `
          .page-content { padding-top: 0 !important; }
          .mobile-menu { display: none !important; }
          body { padding-bottom: 70px !important; } /* Para dejar espacio para los botones de la app */
        `;
        document.head.appendChild(styleElement);
      } catch(e) {
        console.error('Error al ajustar estilos:', e);
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón de retroceso y logo
            Container(
              color: const Color(0xFF111418),
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(width: 95),
                  
                  // Logo
                  Expanded(
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 40.0,
                        ),
                      ),
                    ),
                  ),
                  
                  // Botones de navegación
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _controller.reload();
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.home,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _controller.loadRequest(Uri.parse('https://clinicasloveshop.com/66-promociones-del-mes'));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Barra de navegación con información y botones
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: const Color(0xFF1980E6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Promociones y Tienda Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Botones de navegación web
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (await _controller.canGoBack()) {
                        _controller.goBack();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (await _controller.canGoForward()) {
                        _controller.goForward();
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // WebView principal
            Expanded(
              child: Stack(
                children: [
                  // WebView - AQUÍ ESTÁ EL CAMBIO PRINCIPAL
                  WebViewWidget(controller: _controller),
                  
                  // Indicador de carga
                  if (_isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1980E6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Botones de acción inferiores
            Container(
              padding: const EdgeInsets.all(12.0),
              color: const Color(0xFF293038),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomButton(
                    icon: Icons.shopping_cart,
                    label: 'Carrito',
                    onPressed: () {
                      _controller.loadRequest(Uri.parse('https://clinicasloveshop.com/carrito'));
                    },
                  ),
                  _buildBottomButton(
                    icon: Icons.category,
                    label: 'Categorías',
                    onPressed: () {
                      _controller.loadRequest(Uri.parse('https://clinicasloveshop.com/'));
                    },
                  ),
                  _buildBottomButton(
                    icon: Icons.person,
                    label: 'Mi Cuenta',
                    onPressed: () {
                      _controller.loadRequest(Uri.parse('https://clinicasloveshop.com/mi-cuenta'));
                    },
                  ),
                  _buildBottomButton(
                    icon: Icons.search,
                    label: 'Buscar',
                    onPressed: () {
                      _controller.runJavaScript('''
                        document.querySelector('.search-toggle').click();
                      ''');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}