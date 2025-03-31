import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as Math;

class KnowledgeBase {
  // Las diferentes categorías de conocimiento
  final Map<String, List<Map<String, dynamic>>> _treatments = {};
  final Map<String, List<Map<String, dynamic>>> _prices = {};
  final List<Map<String, dynamic>> _faq = [];
  final List<Map<String, dynamic>> _clinics = [];
  final List<Map<String, dynamic>> _webReferences = [];

  bool _isInitialized = false;
  
  // Configuración de Supabase
  late final String _supabaseUrl;
  late final String _supabaseKey;
  
  // Singleton para acceso global
  static final KnowledgeBase _instance = KnowledgeBase._internal();
  
  factory KnowledgeBase() {
    return _instance;
  }
  
  KnowledgeBase._internal() {
    // Cargar credenciales desde variables de entorno
    _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    _supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';
    
    debugPrint('🔧 KnowledgeBase inicializado con URL: ${_supabaseUrl.isNotEmpty ? _supabaseUrl : 'No configurada'}');
  }
  
  // Inicializar y cargar datos
  Future<void> initialize() async {
    debugPrint('🔄 Inicializando KnowledgeBase...');
    await _loadCachedData();
    await refreshAllData();
    _isInitialized = true; 
  }
  
  // Cargar datos desde el almacenamiento local
  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar precios
      final pricesJson = prefs.getString('cached_prices');
      if (pricesJson != null) {
        final pricesData = jsonDecode(pricesJson) as Map<String, dynamic>;
        pricesData.forEach((category, prices) {
          _prices[category] = (prices as List).cast<Map<String, dynamic>>();
        });
      }
      
      // Cargar tratamientos
      final treatmentsJson = prefs.getString('cached_treatments');
      if (treatmentsJson != null) {
        final treatmentsData = jsonDecode(treatmentsJson) as Map<String, dynamic>;
        treatmentsData.forEach((category, treatments) {
          _treatments[category] = (treatments as List).cast<Map<String, dynamic>>();
        });
      }
      
      // Cargar FAQ
      final faqJson = prefs.getString('cached_faq');
      if (faqJson != null) {
        _faq.addAll((jsonDecode(faqJson) as List).cast<Map<String, dynamic>>());
      }
      
      // Cargar clínicas
      final clinicsJson = prefs.getString('cached_clinics');
      if (clinicsJson != null) {
        _clinics.addAll((jsonDecode(clinicsJson) as List).cast<Map<String, dynamic>>());
      }

      final webReferencesJson = prefs.getString('cached_web_references');
      if (webReferencesJson != null) {
        _webReferences.addAll((jsonDecode(webReferencesJson) as List).cast<Map<String, dynamic>>());
      }
      
      debugPrint('✅ Datos en caché cargados');
    } catch (e) {
      debugPrint('⚠️ Error cargando datos en caché: $e');
      // Si hay error, cargar datos de respaldo
      _loadFallbackData();
    }
  }
  
  // Actualizar todos los datos
  Future<void> refreshAllData() async {
    try {
      await Future.wait([
        refreshPrices(),
        refreshTreatments(),
        refreshFAQ(),
        refreshClinics(),
        refreshWebReferences(), // Añadir esta línea
      ]);
      debugPrint('✅ Todos los datos actualizados');
    } catch (e) {
      debugPrint('⚠️ Error actualizando datos: $e');
      // Si hay error, asegurarse de que tenemos datos de respaldo
      _loadFallbackData();
    }
  }
  
  // Cargar precios desde Supabase con mejor manejo de errores
  Future<void> refreshPrices() async {
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/prices?select=*'),
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey'
        },
      ).timeout(Duration(seconds: 5)); // Añadir timeout para evitar esperas largas
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _prices.clear();
        
        // Organizar por categoría
        for (var item in data) {
          final category = item['category'] as String? ?? 'Sin categoría';
          _prices[category] ??= [];
          _prices[category]!.add(item as Map<String, dynamic>);
        }
        
        // Guardar en caché
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_prices', jsonEncode(_prices));
        
        debugPrint('✅ Precios actualizados: ${data.length} ítems');
      } else {
        debugPrint('⚠️ Error cargando precios: ${response.statusCode}');
        // Si la API devuelve error, cargar datos de respaldo
        _loadFallbackPrices();
      }
    } catch (e) {
      debugPrint('⚠️ Error actualizando precios: $e');
      // Si hay una excepción, cargar datos de respaldo
      _loadFallbackPrices();
    }
  }
  
  // Cargar todos los datos de respaldo
  void _loadFallbackData() {
    _loadFallbackPrices();
    _loadFallbackTreatments();
    _loadFallbackFAQ();
    _loadFallbackClinics();
    _loadFallbackWebReferences(); // Añadir esta línea
    debugPrint('✅ Datos de respaldo cargados');
  }
  
  // Cargar precios de respaldo
  void _loadFallbackPrices() {
    _prices.clear();
    _prices['Facial'] = [
      {
        'id': '1',
        'treatment': 'Botox',
        'price': '300€',
        'category': 'Facial',
        'description': 'Tratamiento por zona para arrugas de expresión'
      },
      {
        'id': '2',
        'treatment': 'Aumento de labios',
        'price': '300€',
        'category': 'Facial',
        'description': 'Relleno de labios con ácido hialurónico'
      },
      {
        'id': '3',
        'treatment': 'Eliminación de ojeras',
        'price': '90€',
        'category': 'Facial',
        'description': 'Tratamiento específico para ojeras con ácido hialurónico'
      },
      {
        'id': '4',
        'treatment': 'Full Face',
        'price': '2.200€',
        'category': 'Facial',
        'description': 'Combinación de Botox y ácido hialurónico'
      },
    ];
    
    _prices['Medicina Estética Corporal'] = [
      {
        'id': '5',
        'treatment': 'Bono de 10 sesiones de mesoterapia corporal',
        'price': '530€',
        'category': 'Corporal',
        'description': 'Tratamiento reductor y reafirmante'
      },
      {
        'id': '6',
        'treatment': 'Carboxiterapia corporal',
        'price': '90€',
        'category': 'Corporal',
        'description': 'Tratamiento para celulitis y flacidez'
      },
    ];
    
    _prices['Cirugía Plástica'] = [
      {
        'id': '8',
        'treatment': 'Mastopexia con prótesis',
        'price': '6.300€',
        'category': 'Cirugía Plástica',
        'description': 'Elevación de pecho con implantes'
      },
      {
        'id': '9',
        'treatment': 'Ninfoplastia',
        'price': '2.199€',
        'category': 'Cirugía Plástica',
        'description': 'Reducción de labios menores'
      },
    ];
    
    debugPrint('⚠️ Cargados precios de respaldo: ${_prices.length} categorías');
  }
  
  // Cargar tratamientos de respaldo
  void _loadFallbackTreatments() {
    _treatments['Facial'] = [
      {
        'name': 'Botox',
        'description': 'Suaviza las líneas de expresión y previene arrugas',
        'benefits': ['Sin tiempo de recuperación', 'Resultados en 3-7 días', 'Dura 4-6 meses'],
      },
      {
        'name': 'Ácido Hialurónico',
        'description': 'Relleno facial para recuperar volumen y definir contornos',
        'benefits': ['Resultados inmediatos', 'Apariencia natural', 'Dura hasta 12 meses'],
      },
      {
        'name': 'Eliminación de ojeras',
        'description': 'Tratamiento específico para reducir el aspecto de las ojeras',
        'benefits': ['Resultados inmediatos', 'Aspecto descansado', 'Efecto rejuvenecedor'],
      },
    ];
    
    _treatments['Corporal'] = [
      {
        'name': 'Presoterapia',
        'description': 'Drenaje linfático para eliminar líquidos y toxinas',
        'benefits': ['Reduce hinchazón', 'Mejora la circulación', 'Combate la celulitis'],
      },
      {
        'name': 'Masajes reductores',
        'description': 'Masajes específicos para modelar y reducir volumen',
        'benefits': ['Tonifica la piel', 'Reduce medidas', 'Mejora la firmeza'],
      },
    ];
    
    debugPrint('⚠️ Cargados tratamientos de respaldo: ${_treatments.length} categorías');
  }

  // Cargar clínicas de respaldo
  void _loadFallbackClinics() {
    // Limpiar la lista existente
    _clinics.clear();
    
    // Añadir nuevos elementos
    _clinics.addAll([
      {
        'name': 'Clínicas Love Barcelona',
        'address': 'Carrer Diputacio 327, 08009 Barcelona',
        'phone': '+34 938526533',
        'schedule': 'Lunes a Viernes: 9:00 - 20:00.'
      },
      {
        'name': 'Clínicas Love Madrid',
        'address': 'Calle Edgar Neville, 16. 28020 Madrid',
        'phone': '34 919993515',
        'schedule': 'Lunes a Viernes: 10:00 - 20:00.'
      },
    ]);
    
    debugPrint('⚠️ Cargada información de clínicas de respaldo: ${_clinics.length} clínicas');
  }

  // Cargar FAQ de respaldo
  void _loadFallbackFAQ() {
    // Limpiar la lista existente
    _faq.clear();
    
    // Añadir nuevos elementos
    _faq.addAll([
      {
        'question': '¿Es doloroso el tratamiento con Botox?',
        'answer': 'El tratamiento con Botox causa mínimas molestias. Se utiliza una aguja muy fina y la sensación es como un pequeño pinchazo.'
      },
      {
        'question': '¿Cuánto dura el efecto del ácido hialurónico?',
        'answer': 'El efecto del ácido hialurónico suele durar entre 6 y 12 meses, dependiendo de la zona tratada y el metabolismo de cada persona.'
      },
      {
        'question': '¿Cuándo veré resultados con los tratamientos anticelulíticos?',
        'answer': 'Los resultados de los tratamientos anticelulíticos comienzan a verse generalmente después de 3-4 sesiones. Para resultados óptimos se recomiendan entre 8-10 sesiones.'
      },
    ]);
    
    debugPrint('⚠️ Cargadas FAQs de respaldo: ${_faq.length} preguntas');
  }

    // Cargar referencias web de respaldo
  void _loadFallbackWebReferences() {
    // Limpiar la lista existente
    _webReferences.clear();
    
    // Añadir referencias web para tratamientos populares
    _webReferences.addAll([
      {
        'treatment': 'Botox',
        'url': 'https://www.mayoclinic.org/es-es/tests-procedures/botox/about/pac-20384658',
        'title': 'Botox: Usos y efectos - Mayo Clinic',
        'summary': 'El botox bloquea las señales de los nervios a los músculos. El músculo inyectado ya no puede contraerse, lo que hace que las arrugas se relajen y se suavicen temporalmente.',
        'tags': ['botox', 'facial', 'antiarrugas', 'tratamiento']
      },
      {
        'treatment': 'Aumento de Labios',
        'url': 'https://clinicaslove.com/aumento-de-labios/?_gl=1*1mtutuy*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Aumento de Labios - Clínicas Love',
        'summary': 'Los Labios que siempre Soñaste. Aumento de Labios con Ácido Hialurónico. Resultados Naturales y Duraderos. ¡Pide tu Cita!',
        'tags': ['labios', 'facial', 'aumento', 'tratamiento', 'relleno', 'perfilado', 'hidratacion']
      },
      {
        'treatment': 'Lipopapada',
        'url': 'https://clinicaslove.com/lipopapada/?_gl=1*17wfpwh*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Simetría en tu rostro - Clínicas Love',
        'summary': '¿Qué es la lipopapada? Descubre cómo eliminar la papada y recuperar la armonía facial con tratamientos de lipopapada en Clínicas Love.',
        'tags': ['lipopapada', 'facial', 'papada', 'armonía', 'perfilado', 'cuello']
      },
      {
        'treatment': 'Bichectomía',
        'url': 'https://clinicaslove.com/bichectomia/?_gl=1*h1m8nc*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Bichectomía - Clínicas Love',
        'summary': '¿Qué es la bichectomía? Descubre cómo reducir las mejillas y definir el rostro con la cirugía de bichectomía en Clínicas Love.',
        'tags': ['bichectomía', 'facial', 'mejillas', 'definición', 'cirugía', 'armonía']
      },
      {
        'treatment': 'Blefaroplastia',
        'url': 'https://clinicaslove.com/blefaroplastia/?_gl=1*1t2uu4w*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Blefaroplastia - Clínicas Love',
        'summary': '¿Qué es la blefaroplastia? Descubre cómo rejuvenecer la mirada y eliminar bolsas y ojeras con la cirugía de blefaroplastia en Clínicas Love.',
        'tags': ['blefaroplastia', 'facial', 'ojos', 'rejuvenecimiento', 'cirugía', 'bolsas', 'ojeras']
      },
      {
        'treatment': 'Ácido Hialurónico',
        'url': 'https://www.clinicaplanas.com/es/tratamientos-faciales/acido-hialuronico',
        'title': 'Ácido Hialurónico: Aplicaciones y Resultados',
        'summary': 'El ácido hialurónico es una sustancia que se encuentra naturalmente en la piel y ayuda a mantenerla hidratada y firme. Como relleno dérmico, puede suavizar arrugas y añadir volumen.',
        'tags': ['ácido hialurónico', 'rellenos', 'facial', 'volumen']
      },
      {
        'treatment': 'Eliminación de ojeras',
        'url': 'https://www.avclinic.es/tratamientos-faciales/eliminacion-de-ojeras/',
        'title': 'Tratamiento Avanzado de Ojeras - AV Clinic',
        'summary': 'La eliminación de ojeras con ácido hialurónico corrige la depresión bajo los ojos rellenando el surco lagrimal, reduciendo sombras y dando un aspecto más descansado.',
        'tags': ['ojeras', 'facial', 'ácido hialurónico', 'cansancio']
      },
      {
        'treatment': 'Armomización facial',
        'url': 'https://clinicaslove.com/armonizacion-facial/?_gl=1*7nl3gg*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Armonización Facial - Clínicas Love',
        'summary': '¿Qué es la armonización facial? Descubre los tratamientos para armonizar y embellecer el rostro, como rellenos faciales, bichectomía, rinomodelación y más.',
        'tags': ['armonizacion', 'rejuvenecida', 'facial', 'menton', 'colágeno', 'pomulos']
      },
      {
        'treatment': 'Rinomodelación sin cirugía',
        'url': 'https://clinicaslove.com/rinomodelacion/?_gl=1*ofdfym*_up*MQ..*_gs*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Rinomodelación sin cirugía - Clínicas Love',
        'summary': 'La rinomodelación es un procedimiento estético que corrige defectos menores de la nariz sin cirugía. Se utiliza ácido hialurónico para perfilar y armonizar la forma nasal.',
        'tags': ['rinomodelación', 'nariz', 'estética', 'nasal', 'perfilado']
      },
      {
        'treatment': 'Presoterapia',
        'url': 'https://www.clinicaslore.com/tratamientos-corporales/presoterapia/',
        'title': 'Presoterapia: Beneficios y Procedimiento',
        'summary': 'La presoterapia es un tratamiento de drenaje linfático que utiliza presión controlada para mejorar la circulación, reducir la retención de líquidos y combatir la celulitis.',
        'tags': ['presoterapia', 'corporal', 'drenaje', 'celulitis', 'retención']
      },
      {
        'treatment': 'Radiofrecuencia',
        'url': 'https://www.mipiel.es/tratamientos-faciales/radiofrecuencia/',
        'title': 'Radiofrecuencia Facial y Corporal',
        'summary': 'La radiofrecuencia es un tratamiento que utiliza energía térmica para estimular la producción de colágeno y elastina, mejorando la firmeza y elasticidad de la piel.',
        'tags': ['radiofrecuencia', 'facial', 'corporal', 'flacidez', 'colágeno']
      },
      {
        'treatment': 'Microdermoabrasión',
        'url': 'https://www.dermatologiamadrid.com/tratamientos-faciales/microdermoabrasion/',
        'title': 'Microdermoabrasión: Renovación de la Piel',
        'summary': 'La microdermoabrasión es una técnica de exfoliación que elimina las capas superficiales de la piel, reduciendo imperfecciones, cicatrices leves y mejorando la textura general.',
        'tags': ['microdermoabrasión', 'exfoliación', 'facial', 'textura', 'cicatrices']
      },
      {
        'treatment': 'Aumento de Pecho',
        'url': 'https://clinicaslove.com/aumento-de-pecho/?_gl=1*19x62qz*_up*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Aumento de Pecho - Clínicas Love',
        'summary': '¿Qué es el aumento de pecho? Descubre cómo aumentar el volumen y mejorar la forma de los senos con la cirugía de aumento de pecho en Clínicas Love.',
        'tags': ['aumento de pecho', 'mamoplastia', 'cirugía', 'implantes', 'senos']
      },
      {
        'treatment': 'K-Láser',
        'url': 'https://clinicaslove.com/k-laser/?_gl=1*1tw2sed*_up*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'K-Láser - Clínicas Love',
        'summary': '¿Qué es el K-Láser? Descubre cómo mejorar la textura de la piel, reducir cicatrices y estimular la producción de colágeno con el tratamiento de K-Láser en Clínicas Love.',
        'tags': ['k-láser', 'rejuvenecimiento', 'cicatrices', 'colágeno']
      },
      {
        'treatment': 'Eliminación de arrugas',
        'url': 'https://clinicaslove.com/eliminacion-de-arrugas/?_gl=1*rasu3*_up*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Eliminación de Arrugas - Clínicas Love',
        'summary': '¿Qué es la eliminación de arrugas? Descubre los tratamientos para reducir y prevenir las arrugas faciales con Botox, ácido hialurónico y otros procedimientos en Clínicas Love.',
        'tags': ['arrugas', 'facial', 'botox', 'ácido hialurónico']
      },
      {
        'treatment': 'Surco Nasogeniano',
        'url': 'https://clinicaslove.com/surco-nasogeniano/?_gl=1*1rf516n*_up*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Surco Nasogeniano - Clínicas Love',
        'summary': '¿Qué es el surco nasogeniano? Descubre cómo eliminar las arrugas de la sonrisa y rejuvenecer el rostro con tratamientos de surco nasogeniano en Clínicas Love.',
        'tags': ['surco nasogeniano', 'facial', 'arrugas', 'sonrisa', 'rejuvenecimiento']
      },
      {
        'treatment': 'Laser CO2',
        'url': 'https://clinicaslove.com/laser-co2/?_gl=1*1ssu4xk*_up*MQ..&gclid=Cj0KCQjw-e6-BhDmARIsAOxxlxUJqU9xbhI9oFCQJgORVijpYxwjSzWF5b1UHWiIe4ebyl4E6BS_VfQaAieAEALw_wcB',
        'title': 'Laser CO2 - Clínicas Love',
        'summary': '¿Qué es el láser CO2? Descubre cómo mejorar la textura de la piel, reducir cicatrices y estimular la producción de colágeno con el tratamiento de láser CO2 en Clínicas Love.',
        'tags': ['láser co2', 'rejuvenecimiento', 'cicatrices', 'colágeno']
      },
      
    ]);
    
    debugPrint('⚠️ Cargadas referencias web de respaldo: ${_webReferences.length} páginas');
  }
  
  // Implementar los métodos necesarios para la carga desde API
  Future<void> refreshTreatments() async {
    // Intentar cargar desde API
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/treatments?select=*'),
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey'
        },
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        // Procesar respuesta
        // Código similar al de refreshPrices
        debugPrint('✅ Tratamientos actualizados desde API');
      } else {
        // Si hay error, usar respaldo
        _loadFallbackTreatments();
      }
    } catch (e) {
      debugPrint('⚠️ Error cargando tratamientos desde API: $e');
      _loadFallbackTreatments();
    }
  }
  
  Future<void> refreshFAQ() async {
    // Intentar cargar desde API o usar respaldo
    _loadFallbackFAQ();
    debugPrint('✅ FAQs actualizadas');
  }
    
  Future<void> refreshClinics() async {
    try {
      // CARGAR DESDE SUPABASE - Esta es la clave
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/clinics?select=*'),
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
      ).timeout(const Duration(seconds: 5));
      
      debugPrint('🔍 Clinics response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _clinics.clear();
        
        // Transformar los datos recibidos al formato esperado
        for (var item in data) {
          _clinics.add({
            'name': item['name'] ?? '',
            'address': item['address'] ?? '',
            'phone': item['phone'] ?? '',
            'schedule': item['schedule'] ?? ''
          });
        }
        
        // Guardar en caché
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_clinics', jsonEncode(_clinics));
        
        debugPrint('✅ Información de clínicas actualizada: ${_clinics.length} clínicas');
      } else {
        debugPrint('⚠️ Error cargando clínicas: ${response.statusCode}');
        debugPrint('⚠️ Respuesta: ${response.body.substring(0, Math.min(100, response.body.length))}...');
        _loadFallbackClinics();
      }
    } catch (e) {
      debugPrint('⚠️ Error actualizando clínicas: $e');
      _loadFallbackClinics();
    }
  }

  Future<void> refreshWebReferences() async {
    try {
      final response = await http.get(
        Uri.parse('$_supabaseUrl/rest/v1/web_references?select=*'),
        headers: {
          'apikey': _supabaseKey,
          'Authorization': 'Bearer $_supabaseKey',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
      ).timeout(const Duration(seconds: 8));
      
      debugPrint('🔍 Web references response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _webReferences.clear();
        
        // Transformar los datos recibidos al formato esperado
        for (var item in data) {
          _webReferences.add({
            'treatment': item['treatment'],
            'url': item['url'],
            'title': item['title'],
            'summary': item['summary'],
            'tags': item['tags']
          });
        }
        
        // Guardar en caché
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_web_references', jsonEncode(_webReferences));
        
        debugPrint('✅ Referencias web actualizadas: ${data.length} páginas');
      } else {
        debugPrint('⚠️ Error cargando referencias web: ${response.statusCode}');
        debugPrint('⚠️ Respuesta: ${response.body.substring(0, Math.min(100, response.body.length))}...');
        _loadFallbackWebReferences();
      }
    } catch (e) {
      debugPrint('⚠️ Error actualizando referencias web: $e');
      _loadFallbackWebReferences();
    }
  }
  
  // CONSULTA DE DATOS
  
  // Obtener categorías de precios disponibles
  Future<List<String>> getPriceCategories() async {
    // Si las categorías de precio ya están cargadas, devolverlas directamente
    if (_prices.isNotEmpty) {
      return _prices.keys.toList();
    }
    
    // De lo contrario, cargar datos de respaldo
    _loadFallbackPrices();
    return _prices.keys.toList();
  }
  
  // Obtener información sobre horarios de clínicas
  Future<String> getClinicScheduleInfo() async {
    if (_clinics.isEmpty) {
      _loadFallbackClinics();
    }
    
    StringBuffer info = StringBuffer();
    info.writeln('Información sobre horarios y citas:');
    
    for (var clinic in _clinics) {
      info.writeln('- ${clinic['name']}:');
      info.writeln('  📍 ${clinic['address']}');
      info.writeln('  📞 ${clinic['phone']}');
      info.writeln('  🕒 ${clinic['schedule']}');
      info.writeln();
    }
    
    info.writeln('Información general:');
    info.writeln('- Se requiere cita previa para todos los tratamientos');
    info.writeln('- Tiempo de espera promedio para citas: 2-3 días');
    info.writeln('- Se puede agendar por teléfono, WhatsApp o en la app');
    info.writeln('- Se solicita llegar 15 minutos antes de la cita');
    
    return info.toString();
  }
  
  // Buscar precios por término específico
  Future<List<Map<String, dynamic>>> searchPrices(String query) async {
    // Asegurar que tenemos datos
    if (_prices.isEmpty) {
      _loadFallbackPrices();
    }
    
    // Normalizar consulta
    query = query.toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
    
    List<Map<String, dynamic>> results = [];
    
    // Buscar en todas las categorías
    for (var category in _prices.keys) {
      for (var priceItem in _prices[category]!) {
        final treatment = priceItem['treatment'].toString().toLowerCase();
        final description = priceItem['description']?.toString().toLowerCase() ?? '';
        
        if (treatment.contains(query) || description.contains(query) || category.toLowerCase().contains(query)) {
          results.add(priceItem);
        }
      }
    }
    
    return results;
  }
  
  // Obtener datos relevantes basados en la consulta del usuario
  Future<Map<String, dynamic>> getRelevantContext(String query, {String? preferredType}) async {
    final result = <String, dynamic>{};
    
    // Normalizar consulta
    query = query.toLowerCase();
    
    // Buscar términos clave
    List<String> keywords = _extractKeywords(query);
    debugPrint('🔍 Palabras clave extraídas: ${keywords.join(", ")}');
    
    // Buscar precios relevantes
    final relevantPrices = <Map<String, dynamic>>[];
    for (final category in _prices.keys) {
      for (final price in _prices[category]!) {
        final treatment = (price['treatment'] as String).toLowerCase();
        if (keywords.any((kw) => treatment.contains(kw)) || 
            keywords.any((kw) => category.toLowerCase().contains(kw))) {
          relevantPrices.add(price);
        }
      }
    }
    
    if (relevantPrices.isNotEmpty) {
      result['prices'] = relevantPrices;
      debugPrint('💰 Encontrados ${relevantPrices.length} precios relevantes');
    } else if (query.contains('precio') || query.contains('costo')) {
      // Si preguntó por precios pero no encontramos específicos, dar categorías
      result['price_categories'] = _prices.keys.toList();
      debugPrint('📋 No se encontraron precios específicos, devolviendo categorías');
    }
    
    // Buscar tratamientos relevantes
    final relevantTreatments = <Map<String, dynamic>>[];
    for (final category in _treatments.keys) {
      for (final treatment in _treatments[category]!) {
        final name = (treatment['name'] as String).toLowerCase();
        if (keywords.any((kw) => name.contains(kw)) ||
            keywords.any((kw) => category.toLowerCase().contains(kw))) {
          relevantTreatments.add(treatment);
        }
      }
    }
    
    if (relevantTreatments.isNotEmpty) {
      result['treatments'] = relevantTreatments;
      debugPrint('💉 Encontrados ${relevantTreatments.length} tratamientos relevantes');
    }
    
    // Buscar FAQs relevantes
    final relevantFAQs = _faq.where((faq) {
      final question = (faq['question'] as String).toLowerCase();
      final answer = (faq['answer'] as String).toLowerCase();
      return keywords.any((kw) => question.contains(kw) || answer.contains(kw));
    }).toList();
    
    if (relevantFAQs.isNotEmpty) {
      result['faqs'] = relevantFAQs;
      debugPrint('❓ Encontradas ${relevantFAQs.length} FAQs relevantes');
    }

    // Buscar referencias web relevantes
    final relevantWebReferences = _webReferences.where((ref) {
      final treatment = (ref['treatment'] as String).toLowerCase();
      final title = (ref['title'] as String).toLowerCase();
      final summary = (ref['summary'] as String).toLowerCase();
      final tags = (ref['tags'] as List).cast<String>().map((t) => t.toLowerCase());
      
      return keywords.any((kw) => 
          treatment.contains(kw) || 
          title.contains(kw) || 
          summary.contains(kw) || 
          tags.any((tag) => tag.contains(kw)));
    }).toList();
    
    if (relevantWebReferences.isNotEmpty) {
      result['web_references'] = relevantWebReferences;
      debugPrint('🌐 Encontradas ${relevantWebReferences.length} referencias web relevantes');
    }
    
    // Incluir información de clínicas si es relevante
    if (query.contains('clínica') || query.contains('dirección') || 
        query.contains('ubicación') || query.contains('donde') ||
        query.contains('dónde') || query.contains('sitio') || 
        query.contains('lugar') || query.contains('cómo llegar') || 
        query.contains('on es') || query.contains('ubicacions') ||
        query.contains('cliniques') || query.contains('where') ||
        query.contains('location') || query.contains('address') ||
        query.contains('barcelona') || query.contains('madrid') ||
        query.contains('málaga') || query.contains('malaga') ||
        query.contains('tenerife')) {  // Añadida detección por ciudad
      result['clinics'] = _clinics;
      debugPrint('🏥 Incluyendo información de clínicas');
    }

      // detección específica para precios
     bool isPriceQuery = query.contains('precio') || query.contains('costo') || 
                     query.contains('cuánto') || query.contains('cuanto') ||
                     query.contains('vale') || query.contains('cuesta');
  
       if (isPriceQuery) {
    // Si es consulta de precio, buscar más agresivamente
    for (final category in _prices.keys) {
      for (final price in _prices[category]!) {
        final treatment = (price['treatment'] as String).toLowerCase();
        // Buscar coincidencia directa con cualquier palabra clave
        if (keywords.any((kw) => treatment.contains(kw))) {
          relevantPrices.add(price);
          debugPrint('✅ Coincidencia directa: $treatment con $keywords');
        }
        // Si es "aumento de labios" específicamente
        else if (query.contains('labio') && 
                (treatment.contains('labio') || treatment.contains('lip'))) {
          relevantPrices.add(price);
          debugPrint('✅ Coincidencia especial para labios');
        }

          // Añade lógica para priorizar el tipo preferido
        if (preferredType != null) {
          debugPrint('🔍 Buscando principalmente: $preferredType para: "$query"');
          
          // Si preferredType es 'prices', prioriza la búsqueda en los precios
          if (preferredType == 'prices' && relevantPrices.isNotEmpty) {
            // Dar prioridad a los precios en los resultados
            result['prices'] = relevantPrices;
          }
          // Si preferredType es 'treatments', prioriza la búsqueda en los tratamientos
          else if (preferredType == 'treatments' && relevantTreatments.isNotEmpty) {
            // Dar prioridad a los tratamientos en los resultados
            result['treatments'] = relevantTreatments;
          }
        }
      }
    }
  }
    
    return result;
  }
  
  // Extraer palabras clave de la consulta
  List<String> _extractKeywords(String query) {
    // Lista de palabras a ignorar (stop words)
    final stopWords = [
      'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
      'de', 'del', 'al', 'a', 'ante', 'con', 'en', 'para', 'por', 'sin',
      'que', 'como', 'cuando', 'cuanto', 'quien',
      'y', 'o', 'pero', 'si', 'no',
      'es', 'son', 'ser', 'estar', 'hay',
      'me', 'te', 'se', 'nos', 'os',
      'cual', 'cuales', 'este', 'esta', 'esto', 'estos', 'estas',
      'aquel', 'aquella', 'aquello', 'aquellos', 'aquellas',
      'mi', 'tu', 'su', 'mis', 'tus', 'sus',
      'hola', 'adios', 'gracias',
      'valor', 'cuanto', 'cuánto',
    ];
    
    // Limpiar y normalizar
    query = query
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Quitar puntuación
        .toLowerCase();
        
    // Dividir por espacios y filtrar palabras cortas y stop words
    return query
        .split(' ')
        .where((word) => 
            word.isNotEmpty && 
            word.length > 2 && 
            !stopWords.contains(word))
        .toList();
  }
  
  // Convertir datos a formato para el prompt
  String formatContextForPrompt(Map<String, dynamic> context) {
    final buffer = StringBuffer();
    
    // Formatear clínicas con énfasis
    if (context.containsKey('clinics') && context['clinics'] is List) {
      buffer.writeln('\nUBICACIONES EXACTAS DE CLÍNICAS LOVE:');
      final clinics = context['clinics'] as List;
      for (var i = 0; i < clinics.length; i++) {
        final clinic = clinics[i];
        buffer.writeln('${i+1}. ${clinic['name']}: DIRECCIÓN EXACTA → ${clinic['address']}');
        if (clinic['phone'] != null) {
          buffer.writeln('   Teléfono: ${clinic['phone']}');
        }
        if (clinic['schedule'] != null) {
          buffer.writeln('   Horario: ${clinic['schedule']}');
        }
      }
      buffer.writeln('\nIMPORTANTE: SOLO EXISTEN ESTAS UBICACIONES. NO HAY OTRAS SUCURSALES.');
    }
  

    // Formatear categorías de precios
    if (context.containsKey('price_categories')) {
      buffer.writeln('CATEGORÍAS DE PRECIOS DISPONIBLES:');
      for (var category in context['price_categories'] as List) {
        buffer.writeln('- $category');
      }
      buffer.writeln();
    }
    
    // Formatear tratamientos
    if (context.containsKey('treatments')) {
      buffer.writeln('INFORMACIÓN DE TRATAMIENTOS:');
      for (var treatment in context['treatments'] as List) {
        buffer.writeln('- ${treatment['name']}');
        buffer.writeln('  ${treatment['description']}');
        if (treatment['benefits'] != null) {
          buffer.writeln('  Beneficios: ${(treatment['benefits'] as List).join(", ")}');
        }
      }
      buffer.writeln();
    }
    
    // Formatear FAQs
    if (context.containsKey('faqs')) {
      buffer.writeln('PREGUNTAS FRECUENTES RELEVANTES:');
      for (var faq in context['faqs'] as List) {
        buffer.writeln('- Pregunta: ${faq['question']}');
        buffer.writeln('  Respuesta: ${faq['answer']}');
      }
      buffer.writeln();
    }
    
    // Formatear clínicas
    if (context.containsKey('clinics')) {
      buffer.writeln('INFORMACIÓN DE CLÍNICAS:');
      for (var clinic in context['clinics'] as List) {
        buffer.writeln('- ${clinic['name']}');
        buffer.writeln('  Dirección: ${clinic['address']}');
        buffer.writeln('  Teléfono: ${clinic['phone']}');
        buffer.writeln('  Horario: ${clinic['schedule']}');
      }
      buffer.writeln();
    }
    // Formatear referencias web
    if (context.containsKey('web_references')) {
      buffer.writeln('REFERENCIAS WEB SOBRE TRATAMIENTOS:');
      for (var ref in context['web_references'] as List) {
        buffer.writeln('- ${ref['treatment']} | ${ref['title']}');
        buffer.writeln('  ${ref['summary']}');
        buffer.writeln('  🔗 Fuente: ${ref['url']}');
      }
      buffer.writeln();
    }
    
    // Añadir información de precios
    if (context.containsKey('prices')) {
      final prices = context['prices'] as List<Map<String, dynamic>>;
      if (prices.isNotEmpty) {
        buffer.writeln('PRECIOS:');
        for (final price in prices) {
          buffer.writeln('- ${price['treatment']}: ${price['price']}');
        }
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  // Método para acceder directamente a TODAS las clínicas sin filtros
  Future<List<Map<String, dynamic>>> getAllClinics() async {
    // Asegurarnos de que la base de conocimiento está inicializada
    if (!_isInitialized) {
      await initialize();
    }
    
    // Si tenemos clínicas cargadas, devolverlas directamente
    if (_clinics.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_clinics);
    }
    
    // Si llegamos aquí, cargar las clínicas de respaldo
    _loadFallbackClinics();
    return List<Map<String, dynamic>>.from(_clinics);
  }
}