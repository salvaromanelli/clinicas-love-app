import 'package:flutter/foundation.dart';
import '/models/medical_references.dart';

/// Servicio para gestionar y recuperar referencias médicas relevantes
class MedicalReferenceService {
  // Almacenamiento en caché de referencias médicas
  final List<MedicalReference> _cachedReferences = [];
  
  MedicalReferenceService() {
    _initializeReferences();
  }
  
  // Inicializar con referencias de ejemplo o cargar desde API/almacenamiento
  void _initializeReferences() {
    // Para simplicidad, usamos ejemplos predefinidos
    _cachedReferences.addAll(MedicalReference.examples);
    debugPrint('📚 Cargadas ${_cachedReferences.length} referencias médicas');
  }
  
  /// Busca referencias médicas relevantes para una consulta específica
  Future<List<MedicalReference>> getRelevantReferences(String query) async {
    // Simular un pequeño retraso para emular una búsqueda real
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Normalizar consulta para búsqueda
    final normalizedQuery = query.toLowerCase();
    
    // Buscar referencias relacionadas con la consulta
    final relevantRefs = _cachedReferences.where((ref) {
      // Verificar coincidencias en título, contenido y etiquetas
      final titleMatches = ref.title.toLowerCase().contains(normalizedQuery);
      final contentMatches = ref.content.toLowerCase().contains(normalizedQuery);
      final tagMatches = ref.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      
      return titleMatches || contentMatches || tagMatches;
    }).toList();
    
    // Ordenar por relevancia
    relevantRefs.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    
    // Limitar número de referencias para no sobrecargar el prompt
    final limitedRefs = relevantRefs.take(3).toList();
    
    debugPrint('🔍 Encontradas ${limitedRefs.length} referencias médicas relevantes para: "$query"');
    return limitedRefs;
  }
  
  /// Añadir una nueva referencia a la colección
  Future<void> addReference(MedicalReference reference) async {
    // Aquí podríamos guardar a una base de datos o API
    _cachedReferences.add(reference);
    debugPrint('✅ Referencia añadida: ${reference.title}');
  }
  
  /// Actualizar la colección de referencias desde una API o base de datos
  Future<void> refreshReferences() async {
    try {
      // En un caso real, aquí harías una petición a una API
      // Por ahora, simplemente simulamos una actualización exitosa
      debugPrint('🔄 Actualizando referencias médicas...');
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('✅ Referencias médicas actualizadas');
    } catch (e) {
      debugPrint('❌ Error actualizando referencias: $e');
      rethrow;
    }
  }
  
  /// Buscar referencias por categoría o etiquetas
  Future<List<MedicalReference>> getReferencesByTags(List<String> tags) async {
    final normalizedTags = tags.map((tag) => tag.toLowerCase()).toList();
    
    return _cachedReferences.where((ref) {
      return ref.tags.any((tag) => 
          normalizedTags.any((searchTag) => tag.toLowerCase().contains(searchTag)));
    }).toList();
  }
}