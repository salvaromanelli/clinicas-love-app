import 'package:uuid/uuid.dart';

/// Representa una referencia médica que se puede usar para enriquecer
/// las respuestas del asistente virtual con información precisa y
/// basada en evidencia.
class MedicalReference {
  /// Identificador único de la referencia
  final String id;
  
  /// Título descriptivo de la referencia
  final String title;
  
  /// Contenido principal de la referencia
  final String content;
  
  /// Fuente o autor de la información
  final String source;
  
  /// Año de publicación (opcional)
  final int? year;
  
  /// URL de la fuente, si está disponible
  final String? url;
  
  /// Categorías o etiquetas para clasificación
  final List<String> tags;
  
  /// Nivel de evidencia médica (1-5, donde 1 es el más alto)
  final int? evidenceLevel;
  
  /// Calificación de relevancia (0-100)
  final int relevanceScore;
  
  /// Crea una nueva referencia médica.
  MedicalReference({
    String? id,
    required this.title,
    required this.content,
    required this.source,
    this.year,
    this.url,
    this.tags = const [],
    this.evidenceLevel,
    this.relevanceScore = 50,
  }) : id = id ?? const Uuid().v4();
  
  /// Convierte la referencia a una representación en formato JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'source': source,
      'year': year,
      'url': url,
      'tags': tags,
      'evidenceLevel': evidenceLevel,
      'relevanceScore': relevanceScore,
    };
  }
  
  /// Crea una referencia médica a partir de un mapa JSON
  factory MedicalReference.fromJson(Map<String, dynamic> json) {
    return MedicalReference(
      id: json['id'] as String?,
      title: json['title'] as String,
      content: json['content'] as String,
      source: json['source'] as String,
      year: json['year'] as int?,
      url: json['url'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      evidenceLevel: json['evidenceLevel'] as int?,
      relevanceScore: json['relevanceScore'] as int? ?? 50,
    );
  }
  
  /// Devuelve una versión formateada de la referencia para el contexto del chat
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write(title);
    
    if (year != null) {
      buffer.write(' ($year)');
    }
    
    buffer.write(': ');
    buffer.write(content);
    
    buffer.write(' [Fuente: $source');
    if (evidenceLevel != null) {
      buffer.write(', Nivel de evidencia: $evidenceLevel');
    }
    buffer.write(']');
    
    return buffer.toString();
  }
  
  /// Crea una copia de esta referencia con los campos especificados modificados
  MedicalReference copyWith({
    String? title,
    String? content,
    String? source,
    int? year,
    String? url,
    List<String>? tags,
    int? evidenceLevel,
    int? relevanceScore,
  }) {
    return MedicalReference(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      source: source ?? this.source,
      year: year ?? this.year,
      url: url ?? this.url,
      tags: tags ?? this.tags,
      evidenceLevel: evidenceLevel ?? this.evidenceLevel,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is MedicalReference &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.source == source &&
        other.year == year &&
        other.url == url &&
        _listEquals(other.tags, tags) &&
        other.evidenceLevel == evidenceLevel &&
        other.relevanceScore == relevanceScore;
  }
  
  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        content.hashCode ^
        source.hashCode ^
        year.hashCode ^
        url.hashCode ^
        tags.hashCode ^
        evidenceLevel.hashCode ^
        relevanceScore.hashCode;
  }
  
  /// Función auxiliar para comparar listas
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  
  /// Ejemplos de referencias predefinidas para pruebas o valores por defecto
  static List<MedicalReference> get examples {
    return [
      MedicalReference(
        title: 'Toxina botulínica (Botox)',
        content: 'La toxina botulínica tipo A es un tratamiento seguro y eficaz para reducir temporalmente las arrugas de expresión. Su efecto dura aproximadamente entre 3 y 6 meses.',
        source: 'American Society of Plastic Surgeons',
        year: 2023,
        evidenceLevel: 1,
        tags: ['botox', 'arrugas', 'facial'],
      ),
      MedicalReference(
        title: 'Ácido hialurónico',
        content: 'Los rellenos de ácido hialurónico son una opción popular para restaurar el volumen facial y suavizar arrugas profundas. La mayoría de los efectos duran entre 6 y 18 meses.',
        source: 'Journal of Clinical and Aesthetic Dermatology',
        year: 2022,
        evidenceLevel: 2,
        tags: ['rellenos', 'facial', 'arrugas'],
      ),
      MedicalReference(
        title: 'Tratamientos láser',
        content: 'Los tratamientos con láser fraccionado pueden mejorar la textura de la piel, reducir cicatrices y estimular la producción de colágeno con un tiempo de recuperación mínimo.',
        source: 'American Academy of Dermatology',
        year: 2023,
        evidenceLevel: 2,
        tags: ['láser', 'rejuvenecimiento', 'cicatrices'],
      ),
    ];
  }
}

/// Colección de referencias médicas que pueden ser consultadas y filtradas
class MedicalReferenceCollection {
  final List<MedicalReference> _references;
  
  MedicalReferenceCollection(this._references);
  
  /// Encuentra referencias relacionadas con una consulta específica
  List<MedicalReference> findRelevantReferences(String query) {
    final normalizedQuery = query.toLowerCase();
    
    // Filtrar por coincidencias en título, contenido o etiquetas
    return _references.where((ref) {
      // Buscar en título y contenido
      if (ref.title.toLowerCase().contains(normalizedQuery) ||
          ref.content.toLowerCase().contains(normalizedQuery)) {
        return true;
      }
      
      // Buscar en etiquetas
      for (final tag in ref.tags) {
        if (tag.toLowerCase().contains(normalizedQuery) ||
            normalizedQuery.contains(tag.toLowerCase())) {
          return true;
        }
      }
      
      return false;
    }).toList()
    // Ordenar por puntuación de relevancia
    ..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }
  
  /// Convierte todas las referencias a formato para prompt de IA
  List<String> toPromptFormat() {
    return _references.map((ref) => ref.toFormattedString()).toList();
  }
}