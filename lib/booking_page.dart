import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/supabase.dart';
import 'models/clinicas.dart';
import 'i18n/app_localizations.dart';
import 'utils/adaptive_sizing.dart'; 

class AppointmentBookingPage extends StatefulWidget {
  final Map<String, dynamic>? initialClinic;
  final Map<String, dynamic>? initialTreatment;
  final Map<String, dynamic>? appointmentToReschedule;
  
  final String? preSelectedTreatmentId;
  final String? preSelectedClinicId;
  final DateTime? preSelectedDate;
  final String? prefilledNotes;

  const AppointmentBookingPage({
    Key? key,
    this.initialClinic,
    this.initialTreatment,
    this.appointmentToReschedule,
    this.preSelectedTreatmentId,
    this.preSelectedClinicId,
    this.preSelectedDate,
    this.prefilledNotes,
  }) : super(key: key);

  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _notesController = TextEditingController();
  late AppLocalizations localizations; 

  List<Map<String, dynamic>> _treatments = [];
  List<dynamic> _clinics = [];
  
  String? _selectedTreatmentId;
  String? _selectedClinicId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentStep = 0;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inicializar localizations cuando el contexto esté disponible
    localizations = AppLocalizations.of(context);
  }

  // Set para almacenar categorías expandidas
  Set<String> _expandedCategories = {};

  // Método para cargar datos iniciales
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Cargar tratamientos
      final treatments = await _supabaseService.getTreatments();
      
      // Cargar clínicas
      final clinics = await _supabaseService.getClinicas();
      
      // Actualizar estado con datos cargados
      setState(() {
        _treatments = treatments;
        _clinics = clinics;
        
        // Configurar selección inicial si se proporcionaron datos
        if (widget.initialTreatment != null) {
          _selectedTreatmentId = widget.initialTreatment!['id'];
        } else if (widget.preSelectedTreatmentId != null) {
          _selectedTreatmentId = widget.preSelectedTreatmentId;
        }
        
        if (widget.initialClinic != null) {
          _selectedClinicId = widget.initialClinic!['id'];
        } else if (widget.preSelectedClinicId != null) {
          _selectedClinicId = widget.preSelectedClinicId;
        }
        
        // Inicializar fechas preseleccionadas
        _selectedDate = widget.preSelectedDate;
        
        // Si hay una cita para reprogramar, tomar sus datos
        if (widget.appointmentToReschedule != null) {
          final appointment = widget.appointmentToReschedule!;
          
          // La fecha ya está en formato DateTime en la DB
          if (appointment['appointment_date'] != null) {
            final date = DateTime.parse(appointment['appointment_date']);
            _selectedDate = date;
            _selectedTime = TimeOfDay(
              hour: date.hour,
              minute: date.minute,
            );
          }
          
          // Tomar las notas de la cita anterior si existen
          if (appointment['notes'] != null) {
            _notesController.text = appointment['notes'];
          }
        } else if (widget.prefilledNotes != null) {
          _notesController.text = widget.prefilledNotes!;
        }
        
        // Expandir automáticamente la categoría del tratamiento seleccionado
        if (_selectedTreatmentId != null) {
          final selectedTreatment = _treatments.firstWhere(
            (t) => t['id'] == _selectedTreatmentId,
            orElse: () => <String, dynamic>{},
          );
          
          if (selectedTreatment.containsKey('category')) {
            _expandedCategories.add(selectedTreatment['category']);
          }
        }
        
        // Expandir la primera categoría por defecto si no hay ninguna seleccionada
        if (_expandedCategories.isEmpty && _treatments.isNotEmpty) {
          final firstCategory = _treatments.first['category'];
          if (firstCategory != null) {
            _expandedCategories.add(firstCategory);
          }
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos iniciales: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.get('error_loading_data'),
              style: TextStyle(fontSize: 14.sp),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Navegar al siguiente paso
  void _nextStep() {
    final isLastStep = _currentStep >= 3;
    
    if (isLastStep) {
      // Ya estamos en el último paso
      return;
    }
    
    // Validar el paso actual antes de continuar
    bool canContinue = true;
    
    switch (_currentStep) {
      case 0: // Tratamiento
        canContinue = _selectedTreatmentId != null;
        if (!canContinue && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('select_treatment_first')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        break;
      case 1: // Clínica
        canContinue = _selectedClinicId != null;
        if (!canContinue && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('select_clinic_first')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        break;
      case 2: // Fecha y hora
        canContinue = _selectedDate != null && _selectedTime != null;
        if (!canContinue && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('select_date_time_first')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        break;
    }
    
    if (canContinue) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  // Navegar al paso anterior
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }

  // Método para reservar la cita
  Future<void> _bookAppointment() async {
    // Validar que todos los campos requeridos estén completos
    if (_selectedTreatmentId == null || 
        _selectedClinicId == null || 
        _selectedDate == null || 
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.get('complete_all_fields')),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Crear objeto DateTime combinando fecha y hora
      final appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      
      // Preparar los datos para la cita
      final appointmentData = {
        'treatment_id': _selectedTreatmentId,
        'clinic_id': _selectedClinicId,
        'appointment_date': appointmentDateTime.toIso8601String(),
        'notes': _notesController.text,
        'status': 'Pendiente'
      };
      
      // Si es una reprogramación, actualizar la cita existente
      if (widget.appointmentToReschedule != null) {
        final appointmentId = widget.appointmentToReschedule!['id'];
        
        // Actualizar status de la cita original a 'Reprogramada'
        await _supabaseService.updateAppointmentStatus(appointmentId, 'Reprogramada');
        
        // Crear una nueva cita con los datos actualizados
        await _supabaseService.createAppointment(appointmentData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('appointment_rescheduled')),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      } else {
        // Crear una nueva cita
        await _supabaseService.createAppointment(appointmentData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.get('appointment_created')),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      }
      
      // Cerrar la pantalla y volver a la anterior indicando éxito
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error al crear la cita: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.get('booking_error')}: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Widget _buildTreatmentSelector() {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    // Obtener categorías únicas y ordenarlas
    final List<String> categories = _treatments
        .map<String>((t) => t['category'] as String)
        .toSet()
        .toList();
    
    // Orden específico de categorías
    final preferredOrder = [
      'Medicina Estética Facial',
      'Cirugía Estética Facial',
      'Cirugía Corporal'
    ];
    
    // Ordenar categorías según el orden preferido
    categories.sort((a, b) {
      final indexA = preferredOrder.indexOf(a);
      final indexB = preferredOrder.indexOf(b);
      if (indexA >= 0 && indexB >= 0) {
        return indexA.compareTo(indexB);
      }
      if (indexA >= 0) return -1;
      if (indexB >= 0) return 1;
      return a.compareTo(b);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('select_treatment'),
          style: TextStyle(
            fontSize: isSmallScreen ? 16.sp : 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.h),
        
        // Check if treatments are available
        _treatments.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medical_services_outlined,
                      size: AdaptiveSize.getIconSize(context, baseSize: 48),
                      color: Colors.white70,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      localizations.get('no_treatments_available'),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _loadInitialData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1980E6),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                      ),
                      child: Text(
                        localizations.get('retry'),
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isExpanded = _expandedCategories.contains(category);
                  
                  // Filtrar tratamientos por categoría
                  final categoryTreatments = _treatments
                      .where((t) => t['category'] == category)
                      .toList();
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 12.h),
                    color: const Color(0xFF1C2126),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.w),
                    ),
                    child: Column(
                      children: [
                        // Header (always visible)
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedCategories.remove(category);
                              } else {
                                _expandedCategories.add(category);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10.w),
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Row(
                              children: [
                                Icon(
                                  category.contains('Cirugía') 
                                      ? Icons.medical_services
                                      : Icons.face,
                                  color: const Color(0xFF1980E6),
                                  size: AdaptiveSize.getIconSize(context, baseSize: 24),
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 15.sp : 16.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: const Color(0xFF1980E6),
                                  size: AdaptiveSize.getIconSize(context, baseSize: 24),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Content (visible only when expanded)
                        if (isExpanded)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Column(
                              children: categoryTreatments.map((treatment) {
                                final isSelected = _selectedTreatmentId == treatment['id'];
                                
                                return Card(
                                  elevation: isSelected ? 3 : 1,
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  color: const Color(0xFF262A33),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.w),
                                    side: BorderSide(
                                      color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                                      width: 2.w,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedTreatmentId = treatment['id'];
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10.w),
                                    child: Padding(
                                      padding: EdgeInsets.all(16.w),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24.w,
                                            height: 24.h,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFF1980E6),
                                                width: 2.w,
                                              ),
                                              color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check,
                                                    size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          SizedBox(width: 16.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  treatment['name'] ?? 'Tratamiento sin nombre',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (treatment['description'] != null)
                                                  Padding(
                                                    padding: EdgeInsets.only(top: 4.h),
                                                    child: Text(
                                                      treatment['description'],
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 12.sp : 14.sp,
                                                        color: Colors.white70,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                if (treatment['price'] != null)
                                                  Padding(
                                                    padding: EdgeInsets.only(top: 8.h),
                                                    child: Text(
                                                      '${treatment['price']}€',
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 15.sp : 16.sp,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF1980E6),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildClinicSelector() {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('select_clinic'),
          style: TextStyle(
            fontSize: isSmallScreen ? 16.sp : 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.h),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _clinics.length,
          itemBuilder: (context, index) {
            final clinic = _clinics[index];
            final isSelected = _selectedClinicId == clinic.id;
            
            return Card(
              elevation: isSelected ? 3 : 1,
              margin: EdgeInsets.only(bottom: 12.h),
              color: const Color(0xFF262A33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.w),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                  width: 2.w,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedClinicId = clinic.id;
                  });
                },
                borderRadius: BorderRadius.circular(10.w),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Container(
                        width: 24.w,
                        height: 24.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1980E6),
                            width: 2.w,
                          ),
                          color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: AdaptiveSize.getIconSize(context, baseSize: 16),
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clinic.nombre ?? 'Clínica sin nombre',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 14.sp : 16.sp,
                                color: Colors.white,
                              ),
                            ),
                            if (clinic.direccion != null)
                              Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Text(
                                  clinic.direccion!,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12.sp : 14.sp,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    final localizations = AppLocalizations.of(context);
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('select_date_time'),
          style: TextStyle(
            fontSize: isSmallScreen ? 16.sp : 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.h),
        // Date picker
        InkWell(
          onTap: () async {
            final DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 90)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF1980E6),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null && mounted) {
              setState(() {
                _selectedDate = pickedDate;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.w),
              color: const Color(0xFF262A33),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: const Color(0xFF1980E6),
                  size: AdaptiveSize.getIconSize(context, baseSize: 24),
                ),
                SizedBox(width: 12.w),
                Text(
                  _selectedDate != null
                      ? dateFormatter.format(_selectedDate!)
                      : localizations.get('select_date'),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                    color: _selectedDate != null ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
        // Time picker
        InkWell(
          onTap: () async {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF1980E6),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedTime != null && mounted) {
              setState(() {
                _selectedTime = pickedTime;
              });
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8.w),
              color: const Color(0xFF262A33),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: const Color(0xFF1980E6),
                  size: AdaptiveSize.getIconSize(context, baseSize: 24),
                ),
                SizedBox(width: 12.w),
                Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : localizations.get('select_time'),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.sp : 16.sp,
                    color: _selectedTime != null ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          localizations.get('office_hours'),
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 12.sp : 14.sp,
          ),
        ),
        if (_selectedDate != null && _selectedDate!.weekday > 5)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              localizations.get('weekend_note'),
              style: TextStyle(
                color: Colors.deepOrange.shade300,
                fontSize: isSmallScreen ? 12.sp : 14.sp,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesAndConfirmation() {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    final localizations = AppLocalizations.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.get('additional_notes'),
          style: TextStyle(
            fontSize: isSmallScreen ? 16.sp : 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 12.h),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: localizations.get('add_appointment_info'),
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.w),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.w),
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.w),
              borderSide: BorderSide(color: const Color(0xFF1980E6)),
            ),
            filled: true,
            fillColor: const Color(0xFF262A33),
          ),
          style: TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        SizedBox(height: 24.h),
        Text(
          localizations.get('appointment_summary'),
          style: TextStyle(
            fontSize: isSmallScreen ? 16.sp : 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF262A33),
            borderRadius: BorderRadius.circular(8.w),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Tratamiento:',
                _treatments
                    .firstWhere(
                        (t) => t['id'] == _selectedTreatmentId,
                        orElse: () => {'name': 'No seleccionado'})['name'],
                isSmallScreen,
              ),
              SizedBox(height: 8.h),
              _buildSummaryRow(
                'Clínica:',
                _clinics
                    .firstWhere(
                        (c) => c.id == _selectedClinicId,
                        orElse: () => Clinica(
                          id: '',
                          nombre: 'No seleccionada',
                          direccion: '',
                          telefono: '',
                          latitud: 0.0,
                          longitud: 0.0,
                        ))
                    .nombre,
                isSmallScreen,
              ),
              SizedBox(height: 8.h),
              _buildSummaryRow(
                'Fecha:',
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'No seleccionada',
                isSmallScreen,
              ),
              SizedBox(height: 8.h),
              _buildSummaryRow(
                'Hora:',
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'No seleccionada',
                isSmallScreen,
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _bookAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1980E6),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.w),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    localizations.get('confirm_appointment'),
                    style: TextStyle(fontSize: isSmallScreen ? 14.sp : 16.sp),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String? value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 13.sp : 14.sp,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value ?? localizations.get('not_selected'),
            style: TextStyle(
              fontSize: isSmallScreen ? 13.sp : 14.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inicializar AdaptiveSize
    AdaptiveSize.initialize(context);
    
    // Determinar si es pantalla pequeña
    final isSmallScreen = AdaptiveSize.screenWidth < 360;
    
    final localizations = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111418), // Color de fondo oscuro
      appBar: AppBar(
        title: Text(
          localizations.get('schedule_appointment'),
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18.sp : 20.sp,
          ),
        ),
        backgroundColor: const Color(0xFF1C2126),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: AdaptiveSize.getIconSize(context, baseSize: 24),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1980E6)),
            )
          : Form(
              key: _formKey,
              child: Theme(
                data: ThemeData(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF1980E6),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1C2126),
                    onSurface: Colors.white,
                  ),
                  canvasColor: const Color(0xFF111418),
                ),
                child: Stepper(
                  currentStep: _currentStep,
                  onStepTapped: (step) {
                    setState(() {
                      _currentStep = step;
                    });
                  },
                  onStepContinue: _nextStep,
                  onStepCancel: _previousStep,
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: EdgeInsets.only(top: 20.h),
                      child: Row(
                        children: [
                          if (details.currentStep < 3)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: details.onStepContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1980E6),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),
                                ),
                                child: Text(
                                  localizations.get('next'),
                                  style: TextStyle(fontSize: isSmallScreen ? 14.sp : 16.sp),
                                ),
                              ),
                            ),
                          if (details.currentStep > 0) ...[
                            SizedBox(width: 12.w),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: details.onStepCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1980E6),
                                  side: BorderSide(color: const Color(0xFF1980E6)),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16.w,
                                    vertical: 12.h,
                                  ),
                                ),
                                child: Text(
                                  localizations.get('previous'),
                                  style: TextStyle(fontSize: isSmallScreen ? 14.sp : 16.sp),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: Text(
                        localizations.get('treatment'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                          color: Colors.white,
                        ),
                      ),
                      content: _buildTreatmentSelector(),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: Text(
                        localizations.get('clinic'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                          color: Colors.white,
                        ),
                      ),
                      content: _buildClinicSelector(),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: Text(
                        localizations.get('date_time'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                          color: Colors.white,
                        ),
                      ),
                      content: _buildDateTimeSelector(),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: Text(
                        localizations.get('confirm'),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14.sp : 16.sp,
                          color: Colors.white,
                        ),
                      ),
                      content: _buildNotesAndConfirmation(),
                      isActive: _currentStep >= 3,
                      state: StepState.indexed,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}