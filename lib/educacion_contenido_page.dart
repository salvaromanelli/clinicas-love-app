import 'package:flutter/material.dart';
import 'utils/adaptive_sizing.dart'; // Importar AdaptiveSize
import 'i18n/app_localizations.dart'; // Para traducciones

class EducacionContenidoPage extends StatelessWidget {
  const EducacionContenidoPage({super.key});

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
            
            // Encabezado de sección
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AdaptiveSize.w(isSmallScreen ? 16 : 24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.get('aesthetics') ?? 'Estética',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AdaptiveSize.sp(isSmallScreen ? 18 : 20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings, 
                      color: Colors.white,
                      size: AdaptiveSize.getIconSize(context, baseSize: 22),
                    ),
                    constraints: BoxConstraints(
                      minWidth: AdaptiveSize.w(40),
                      minHeight: AdaptiveSize.h(40),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Contenido principal
            Expanded(
              child: SingleChildScrollView(
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
                    
                    // Tarjeta de contenido
                    Container(
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
                          // Imagen de portada
                          Image.network(
                            'https://oaidalleapiprodscus.blob.core.windows.net/private/org-JsMmTpMTupl8qQOeSP9nxnyl/user-Z8HSZWg342MFjGWDLCusJSCE/img-tfVujg5dxnzF1uE7ZTmCv0f9.png',
                            height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: AdaptiveSize.w(2),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: AdaptiveSize.h(isSmallScreen ? 160 : 200),
                                color: Colors.grey[800],
                                child: Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    size: AdaptiveSize.getIconSize(context, baseSize: 40),
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Contenido de texto
                          Padding(
                            padding: EdgeInsets.all(AdaptiveSize.w(isSmallScreen ? 16 : 24)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localizations.get('all_about_beauty_treatments') ?? 
                                      'Todo sobre los tratamientos de belleza',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 16 : 18),
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 12 : 16)),
                                Text(
                                  localizations.get('discover_beauty_world') ?? 
                                      'Descubre el mundo de los tratamientos de belleza y conoce los mejores consejos para cuidar tu piel.',
                                  style: TextStyle(
                                    color: const Color(0xFF9DABB8),
                                    fontSize: AdaptiveSize.sp(isSmallScreen ? 14 : 16),
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(height: AdaptiveSize.h(isSmallScreen ? 20 : 24)),
                                
                                // Botón de acción
                                ElevatedButton(
                                  onPressed: () {},
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
                    ),
                    
                    // Espacio para contenido adicional
                    SizedBox(height: AdaptiveSize.h(24)),
                    
                    // Ejemplo de artículo adicional (puedes agregar más contenido aquí)
                    _buildArticleCard(
                      context,
                      isSmallScreen,
                      localizations.get('facial_treatments') ?? 'Tratamientos faciales',
                      localizations.get('facial_treatments_desc') ?? 
                          'Aprende sobre los diferentes tipos de tratamientos faciales y cómo pueden ayudarte a mantener una piel radiante.',
                      'https://oaidalleapiprodscus.blob.core.windows.net/private/org-JsMmTpMTupl8qQOeSP9nxnyl/user-Z8HSZWg342MFjGWDLCusJSCE/img-v2UwP5PUFdGSe9P5sZJtc9Xl.png?st=2023-04-18T19%3A03%3A05Z&se=2023-04-18T21%3A03%3A05Z&sp=r&sv=2021-08-06&sr=b&rscd=inline&rsct=image/png&skoid=6aaadede-4fb3-4698-a8f6-684d7786b067&sktid=a48cca56-e6da-484e-a814-9c849652bcb3&skt=2023-04-17T22%3A51%3A32Z&ske=2023-04-18T22%3A51%3A32Z&sks=b&skv=2021-08-06&sig=qyASsX7tCRnmTyXvTYd1E5vf5qqXZ9oPc8AZiJCX6WA%3D',
                    ),
                    
                    SizedBox(height: AdaptiveSize.h(20)),
                    
                    _buildArticleCard(
                      context,
                      isSmallScreen,
                      localizations.get('body_care') ?? 'Cuidado corporal',
                      localizations.get('body_care_desc') ?? 
                          'Consejos y técnicas para mantener tu cuerpo saludable y en perfectas condiciones.',
                      'https://oaidalleapiprodscus.blob.core.windows.net/private/org-JsMmTpMTupl8qQOeSP9nxnyl/user-Z8HSZWg342MFjGWDLCusJSCE/img-v2YdJxaS1fQE7gqBt6hv5KOY.png?st=2023-04-18T19%3A03%3A55Z&se=2023-04-18T21%3A03%3A55Z&sp=r&sv=2021-08-06&sr=b&rscd=inline&rsct=image/png&skoid=6aaadede-4fb3-4698-a8f6-684d7786b067&sktid=a48cca56-e6da-484e-a814-9c849652bcb3&skt=2023-04-17T22%3A30%3A13Z&ske=2023-04-18T22%3A30%3A13Z&sks=b&skv=2021-08-06&sig=1G2m88RxORiIzxSVAw5YjqZPrfN7j8pnfGcGqLGWGrU%3D',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget para construir tarjetas de artículos adicionales
  Widget _buildArticleCard(BuildContext context, bool isSmallScreen, String title, String description, String imageUrl) {
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
          // Imagen del artículo
          Image.network(
            imageUrl,
            height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: AdaptiveSize.w(2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: AdaptiveSize.h(isSmallScreen ? 120 : 150),
                color: Colors.grey[800],
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    size: AdaptiveSize.getIconSize(context, baseSize: 30),
                    color: Colors.white70,
                  ),
                ),
              );
            },
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
                  onPressed: () {},
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
                    'Leer más',
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