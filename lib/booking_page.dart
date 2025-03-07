import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/supabase.dart';
import 'models/clinicas.dart';

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

// Actualiza el método _loadInitialData() para usar los nuevos parámetros

Future<void> _loadInitialData() async {
  setState(() {
    _isLoading = true;
  });
  
  try {
    // Cargar tratamientos y clínicas desde Supabase
    final treatments = await _supabaseService.getTreatments();
    final clinics = await _supabaseService.getClinicas();
    
    setState(() {
      _treatments = treatments;
      _clinics = clinics;
      
      // Configurar valores iniciales desde los parámetros existentes
      if (widget.initialTreatment != null) {
        _selectedTreatmentId = widget.initialTreatment!['id'];
      }
      
      if (widget.initialClinic != null) {
        _selectedClinicId = widget.initialClinic!['id'];
      }
      
      // Configurar valores desde los nuevos parámetros del asistente virtual
      if (widget.preSelectedTreatmentId != null) {
        _selectedTreatmentId = widget.preSelectedTreatmentId;
      }
      
      if (widget.preSelectedClinicId != null) {
        _selectedClinicId = widget.preSelectedClinicId;
      }
      
      if (widget.preSelectedDate != null) {
        _selectedDate = widget.preSelectedDate;
        _selectedTime = TimeOfDay.fromDateTime(widget.preSelectedDate!);
      }
      
      if (widget.prefilledNotes != null) {
        _notesController.text = widget.prefilledNotes!;
      }
      
      // Si estamos reprogramando una cita, cargar los datos de esa cita
      if (widget.appointmentToReschedule != null) {
        _loadAppointmentToReschedule(widget.appointmentToReschedule!);
      }
      
      _isLoading = false;
    });
  } catch (e) {
    print('Error cargando datos iniciales: $e');
    setState(() {
      _isLoading = false;
    });
    // Mostrar mensaje de error si el widget sigue montado
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }
}

// Método auxiliar para cargar los datos de una cita a reprogramar
void _loadAppointmentToReschedule(Map<String, dynamic> appointment) {
  _selectedTreatmentId = appointment['treatment_id'];
  _selectedClinicId = appointment['clinic_id'];
  
  // Si la cita tiene notas, cargarlas
  if (appointment['notes'] != null && appointment['notes'].toString().isNotEmpty) {
    _notesController.text = appointment['notes'];
  }
  
  // Opcionalmente, puedes extraer la fecha y hora de la cita original
  // pero normalmente querrás que el usuario seleccione una nueva fecha
  // final originalDate = DateTime.parse(appointment['appointment_date']);
  // _selectedDate = originalDate;
  // _selectedTime = TimeOfDay.fromDateTime(originalDate);
}

  Future<void> _bookAppointment() async {
    if (_formKey.currentState?.validate() != true || 
        _selectedTreatmentId == null ||
        _selectedClinicId == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos requeridos')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create a combined date time
      final DateTime appointmentDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await _supabaseService.bookAppointment(
        treatmentId: _selectedTreatmentId!,
        clinicId: _selectedClinicId!,
        date: appointmentDateTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita agendada con éxito')),
        );
        // Navigate back to appointments page
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al agendar cita: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep += 1;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep -= 1;
      });
    }
  }


Set<String> _expandedCategories = {};

Widget _buildTreatmentSelector() {
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
      const Text(
        'Seleccione el tratamiento',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 16),
      
      // Check if treatments are available
      _treatments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay tratamientos disponibles',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInitialData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1980E6),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reintentar'),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                category.contains('Cirugía') 
                                    ? Icons.medical_services
                                    : Icons.face,
                                color: const Color(0xFF1980E6),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: const Color(0xFF1980E6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Content (visible only when expanded)
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Column(
                            children: categoryTreatments.map((treatment) {
                              final isSelected = _selectedTreatmentId == treatment['id'];
                              
                              return Card(
                                elevation: isSelected ? 3 : 1,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTreatmentId = treatment['id'];
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF1980E6),
                                              width: 2,
                                            ),
                                            color: isSelected ? const Color(0xFF1980E6) : Colors.white,
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                treatment['name'] ?? 'Tratamiento sin nombre',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (treatment['description'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    treatment['description'],
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              if (treatment['price'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Text(
                                                    '${treatment['price']}€',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1980E6),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleccione la clínica',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _clinics.length,
          itemBuilder: (context, index) {
            final clinic = _clinics[index];
            final isSelected = _selectedClinicId == clinic.id;
            
            return Card(
              elevation: isSelected ? 3 : 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1980E6) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedClinicId = clinic.id;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1980E6),
                            width: 2,
                          ),
                          color: isSelected ? const Color(0xFF1980E6) : Colors.white,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                            clinic.nombre ?? 'Clínica sin nombre',  // Change from clinic.name to clinic.nombre
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (clinic.direccion != null)  // Change from clinic.address to clinic.direccion
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                clinic.direccion!,  // Change from clinic.address to clinic.direccion
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
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
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleccione fecha y hora',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF1980E6)),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? dateFormatter.format(_selectedDate!)
                      : 'Seleccionar fecha',
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        _selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Time picker
        InkWell(
          onTap: () async {
            final TimeOfDay? pickedTime = await showTimePicker(
              context: context,
              initialTime: _selectedTime ?? TimeOfDay(hour: 9, minute: 0),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFF1980E6)),
                const SizedBox(width: 12),
                Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Seleccionar hora',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedTime != null ? Colors.black : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Horario de atención: 9:00 AM - 7:00 PM',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        if (_selectedDate != null && _selectedDate!.weekday > 5)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Nota: Los fines de semana pueden tener horarios limitados',
              style: TextStyle(
                color: Colors.deepOrange,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesAndConfirmation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notas adicionales',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            hintText: 'Agregue cualquier información adicional para su cita',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        const Text(
          'Resumen de cita',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildSummaryRow(
                'Tratamiento:',
                _treatments
                    .firstWhere(
                        (t) => t['id'] == _selectedTreatmentId,
                        orElse: () => {'name': 'No seleccionado'})['name'],
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Clínica:',
                _clinics
                    .firstWhere(
                        (c) => c.id == _selectedClinicId,
                        orElse: () => Clinica(
                          id: '',
                          nombre: 'No seleccionada', // Changed from 'name' to 'nombre'
                          direccion: '', // Required parameter
                          telefono: '', // Required parameter
                          latitud: 0.0, // Required parameter
                          longitud: 0.0, // Required parameter
                        ))
                    .nombre, // Note: You may need to change this to .nombre if that's the property name
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Fecha:',
                _selectedDate != null
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'No seleccionada',
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Hora:',
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : 'No seleccionada',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _bookAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1980E6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Confirmar cita',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value ?? 'No seleccionado'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agendar Cita',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1980E6),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1980E6)),
            )
          : Form(
              key: _formKey,
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
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        if (details.currentStep < 3)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1980E6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Siguiente'),
                            ),
                          ),
                        if (details.currentStep > 0) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1980E6),
                              ),
                              child: const Text('Anterior'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Tratamiento'),
                    content: _buildTreatmentSelector(),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0
                        ? StepState.complete
                        : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Clínica'),
                    content: _buildClinicSelector(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1
                        ? StepState.complete
                        : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Fecha y Hora'),
                    content: _buildDateTimeSelector(),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2
                        ? StepState.complete
                        : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Confirmar'),
                    content: _buildNotesAndConfirmation(),
                    isActive: _currentStep >= 3,
                    state: StepState.indexed,
                  ),
                ],
              ),
            ),
    );
  }
}