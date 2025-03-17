import 'package:flutter/foundation.dart';

class MedicalReference {
  final String title;
  final String url;
  final List<String> keywords;
  
  MedicalReference({
    required this.title, 
    required this.url, 
    required this.keywords
  });
}

class MedicalReferenceService {
  final List<MedicalReference> references = [
    MedicalReference(
      title: 'Guía de tratamientos de blanqueamiento dental',
      url: 'https://clinicaslove.com/articulos/blanqueamiento-dental',
      keywords: ['blanqueamiento', 'dental', 'dientes', 'blancos', 'estética dental'],
    ),
    MedicalReference(
      title: 'Todo sobre tratamientos de ortodoncia',
      url: 'https://clinicaslove.com/articulos/ortodoncia',
      keywords: ['ortodoncia', 'brackets', 'alineadores', 'invisalign', 'dientes'],
    ),
    MedicalReference(
      title: 'Botox: Usos y beneficios en tratamientos estéticos',
      url: 'https://clinicaslove.com/articulos/botox-estetico',
      keywords: ['botox', 'arrugas', 'toxina botulínica', 'facial', 'estético'],
    ),
    // Añade más referencias según necesites
  ];
  
  List<MedicalReference> getRelevantReferences(String query) {
    query = query.toLowerCase();
    
    List<MedicalReference> relevantRefs = references.where((ref) {
      return ref.keywords.any((keyword) => query.contains(keyword.toLowerCase()));
    }).toList();
    
    if (relevantRefs.length > 3) {
      relevantRefs = relevantRefs.sublist(0, 3);
    }
    
    return relevantRefs;
  }
  
  List<String> referencesToUrlList(List<MedicalReference> refs) {
    return refs.map((ref) => ref.url).toList();
  }
}