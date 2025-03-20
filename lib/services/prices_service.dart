import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PriceService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _cacheKey = 'cached_prices';
  static const int _cacheValidityHours = 24; // Caché válido por 24 horas

/// Busca precios que coincidan con un término específico usando búsqueda flexible
Future<List<Map<String, dynamic>>> searchPrices(String query) async {
  try {
    print('🔍 Buscando precios para: "$query"');
    
    // Normalizar la consulta: minúsculas y eliminar acentos
    final normalizedQuery = query.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
    
    // Obtener todos los precios usando el método existente
    final pricesMap = await getPrices();
    final allPrices = <Map<String, dynamic>>[];
    
    // Aplanar la estructura anidada de precios para buscar
    pricesMap.forEach((category, treatmentsMap) {
      treatmentsMap.forEach((treatment, details) {
        allPrices.add({
          'treatment': treatment,
          'category': category,
          'price': details['price'],
          'description': details['description'] ?? '',
        });
      });
    });
    
    print('📊 Precios totales en DB: ${allPrices.length}');
    
    // Buscar coincidencias parciales
    final results = allPrices.where((price) {
      final treatment = (price['treatment'] as String).toLowerCase();
      final description = price['description'] != null 
          ? (price['description'] as String).toLowerCase() 
          : '';
      final category = price['category'] as String? ?? '';
          
      // Comprobar si la consulta está contenida en cualquier campo
      final isMatch = treatment.contains(normalizedQuery) || 
             description.contains(normalizedQuery) ||
             category.toLowerCase().contains(normalizedQuery);
             
      if (isMatch) {
        print('✅ Coincidencia encontrada: ${price['treatment']}');
      }
      
      return isMatch;
    }).toList();
    
    print('🔍 Resultados encontrados: ${results.length}');
    return results;
  } catch (e) {
    print('❌ Error en searchPrices: $e');
    return [];
  }
}

/// Obtiene las categorías disponibles
Future<List<String>> getCategories() async {
  try {
    // Usar el método existente para obtener precios
    final pricesMap = await getPrices();
    // Retornar las claves, que son las categorías
    return pricesMap.keys.toList();
  } catch (e) {
    print('Error en getCategories: $e');
    return ['Facial', 'Corporal', 'Productos']; // Categorías por defecto si hay error
  }
}  
     
Future<Map<String, Map<String, dynamic>>> getPrices({bool forceRefresh = false}) async {
  // Intentar obtener de caché primero si no se fuerza actualización
  if (!forceRefresh) {
    final cachedData = await _getCachedPrices();
    if (cachedData != null) {
      debugPrint('Usando precios en caché (${cachedData.length} categorías)');
      return cachedData;
    }
  }
  
  // Si no hay caché válido o se fuerza actualización, obtener de Supabase
  try {
    debugPrint('Obteniendo precios desde Supabase...');
    final data = await _client
        .from('prices')
        .select('id, category, treatment, price, description')
        .order('category');
    
    // Transformar los datos a la estructura que necesitamos
    final Map<String, Map<String, dynamic>> prices = {};
    
    for (var item in data) {
      final category = item['category'] ?? 'General';
      final treatment = item['treatment'] ?? '';
      final price = item['price']?.toString() ?? '';
      final description = item['description'] ?? '';
      
      if (treatment.isNotEmpty && price.isNotEmpty) {
        if (!prices.containsKey(category)) {
          prices[category] = {};
        }
        
        prices[category]![treatment] = {
          'price': price,
          'description': description,
        };
      }
    }
    
    // Guardar en caché
    await _cachePrices(prices);
    
    debugPrint('Precios obtenidos: ${prices.length} categorías');
    return prices;
  } catch (e) {
    debugPrint('Error obteniendo precios: $e');
    
    // En caso de error, intentar usar la caché aunque esté vencida
    final cachedData = await _getCachedPrices(ignoreExpiry: true);
    if (cachedData != null) {
      debugPrint('Usando caché vencido como fallback');
      return cachedData;
    }
    
    // Si no hay caché, proporcionar datos de prueba mientras desarrollas
    return {
      'Estética': {
        'Botox': {'price': '€300', 'description': 'Por zona'},
        'Rellenos': {'price': '€450', 'description': 'Por jeringa'}
      },
      'Dental': {
        'Limpieza': {'price': '€80', 'description': 'Profesional'},
        'Blanqueamiento': {'price': '€250', 'description': 'Sesión completa'}
      }
    };
  }
}
  
  Future<void> _cachePrices(Map<String, Map<String, dynamic>> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': prices
    };
    await prefs.setString(_cacheKey, jsonEncode(cacheData));
    debugPrint('Precios guardados en caché');
  }
  
  Future<Map<String, Map<String, dynamic>>?> _getCachedPrices({bool ignoreExpiry = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString(_cacheKey);
    
    if (cachedString == null) {
      return null;
    }      
    
    try {
      final cachedMap = jsonDecode(cachedString) as Map<String, dynamic>;
      final timestamp = cachedMap['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Verificar si el caché expiró (24 horas)
      final expired = now - timestamp > _cacheValidityHours * 60 * 60 * 1000;
      
      if (expired && !ignoreExpiry) {
        debugPrint('Caché de precios expirado');
        return null;
      }
      
      final data = cachedMap['data'] as Map<String, dynamic>;
      final Map<String, Map<String, dynamic>> prices = {};
      
      data.forEach((category, treatments) {
        prices[category] = Map<String, dynamic>.from(treatments as Map);
      });
      
      return prices;
    } catch (e) {
      debugPrint('Error procesando caché: $e');
      return null;
    }
  }
  
  // Método para buscar un precio específico
  Future<Map<String, dynamic>?> findTreatmentPrice(String query) async {
    final prices = await getPrices();
    query = query.toLowerCase();
    
    for (var category in prices.keys) {
      for (var treatment in prices[category]!.keys) {
        if (treatment.toLowerCase().contains(query)) {
          final result = prices[category]![treatment];
          return {
            'treatment': treatment,
            'category': category,
            'price': result['price'],
            'description': result['description'],
          };
        }
      }
    }
    
    return null;
  }
  
  // Método para obtener todos los tratamientos de una categoría
  Future<List<Map<String, dynamic>>> getTreatmentsByCategory(String category) async {
    final prices = await getPrices();
    final results = <Map<String, dynamic>>[];
    
    if (prices.containsKey(category)) {
      prices[category]!.forEach((treatment, details) {
        results.add({
          'treatment': treatment,
          'category': category,
          'price': details['price'],
          'description': details['description'],
        });
      });
    }
    
    return results;
  }
}
