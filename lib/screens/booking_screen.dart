import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'customers_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final CalendarController _calendarController = CalendarController();
  List<Appointment> _appointments = [];
  Map<Appointment, String> _appointmentIdMap = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _alertMessage;
  Color? _alertColor;

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  String _searchTerm = '';
  Map<String, dynamic>? _selectedCustomer;

  static const String backendUrl = 'http://192.168.0.25:3210/api';

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _calendarController.selectedDate = DateTime.now();
    _fetchAppointments();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse('$backendUrl/customers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> customersData = json.decode(response.body);
        setState(() {
          _customers = customersData.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      print('Error fetching customers: $e');
    }
  }

  void _filterCustomers(String term) {
    if (term.isEmpty) {
      setState(() {
        _filteredCustomers = [];
      });
      return;
    }

    final lowerCaseTerm = term.toLowerCase();
    final filtered = _customers.where((customer) {
      final fullName = customer['fullName']?.toString().toLowerCase() ?? '';
      final phoneNumber =
          customer['phoneNumber']?.toString().toLowerCase() ?? '';
      return fullName.contains(lowerCaseTerm) ||
          phoneNumber.contains(lowerCaseTerm);
    }).toList();

    setState(() {
      _filteredCustomers = filtered;
    });
  }

  String _formatDateWithTimezone(DateTime dateTime) {
    final offset = dateTime.timeZoneOffset;
    final offsetSign = offset.isNegative ? '-' : '+';
    final offsetHours = offset.abs().inHours.toString().padLeft(2, '0');
    final offsetMinutes = (offset.abs().inMinutes % 60).toString().padLeft(
      2,
      '0',
    );

    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}T${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}$offsetSign$offsetHours:$offsetMinutes';
  }

  DateTime _parseDateFromBackend(String dateString) {
    DateTime parsedDate = DateTime.parse(dateString);

    if (parsedDate.isUtc) {
      return parsedDate.toLocal();
    }

    return parsedDate;
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.post(
        Uri.parse('$backendUrl/appointments/date'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'date': _formatDateWithTimezone(_selectedDate)}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> appointmentsData = json.decode(response.body);

        List<Appointment> fetchedAppointments = [];
        _appointmentIdMap.clear();

        for (var data in appointmentsData) {
          final appointment = Appointment(
            startTime: _parseDateFromBackend(data['dateFrom']),
            endTime: _parseDateFromBackend(data['dateTo']),
            subject:
                '${data['customer']['fullName']} - ${data['customer']['phoneNumber']}',
            color: Colors.green[700]!,
          );
          fetchedAppointments.add(appointment);
          _appointmentIdMap[appointment] = data['_id'];
        }

        setState(() {
          _appointments = fetchedAppointments;
          _isLoading = false;
        });
      } else {
        _loadSampleAppointments();
      }
    } catch (e) {
      _loadSampleAppointments();
    }
  }

  void _loadSampleAppointments() {
    List<Appointment> sampleAppointments = [
      Appointment(
        startTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          9,
          0,
        ),
        endTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          9,
          30,
        ),
        subject: 'John Doe - 123-456-7890',
        color: Colors.green[700]!,
      ),
      Appointment(
        startTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          11,
          20,
        ),
        endTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          11,
          50,
        ),
        subject: 'Jane Smith - 098-765-4321',
        color: Colors.green[700]!,
      ),
      Appointment(
        startTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          14,
          40,
        ),
        endTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          15,
          10,
        ),
        subject: 'Mike Johnson - 555-123-4567',
        color: Colors.green[700]!,
      ),
    ];

    setState(() {
      _appointments = sampleAppointments;
      _isLoading = false;
      _alertMessage = 'Using sample data - API connection failed';
      _alertColor = Colors.orange;
    });
    _showAlert();
  }

  void _showAlert() {
    if (_alertMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_alertMessage!),
          backgroundColor: _alertColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onCalendarTapped(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.calendarCell) {
      _showAddAppointmentDialog(details.date!);
    } else if (details.targetElement == CalendarElement.appointment) {
      _showAppointmentDetails(details.appointments!.first);
    }
  }

  void _showAddAppointmentDialog(DateTime selectedDateTime) {
    _selectedCustomer = null;
    _searchTerm = '';
    _filteredCustomers = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              title: const Text(
                'Dodaj termin',
                style: TextStyle(color: Color(0xFF1F7A1F)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Izbran datum in čas:',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${selectedDateTime.day.toString().padLeft(2, '0')}.${selectedDateTime.month.toString().padLeft(2, '0')}.${selectedDateTime.year} ob ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Stranka:',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    _buildCustomerAutocomplete(setDialogState),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Prekliči',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_selectedCustomer != null) {
                      Navigator.of(context).pop();
                      await _addAppointmentWithCustomer(
                        selectedDateTime,
                        _selectedCustomer!,
                      );
                    } else {
                      setState(() {
                        _alertMessage = 'Prosimo, izberite stranko.';
                        _alertColor = Colors.red;
                      });
                      _showAlert();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F7A1F),
                  ),
                  child: const Text(
                    'Dodaj',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerAutocomplete(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedCustomer == null) ...[
          TextField(
            decoration: InputDecoration(
              hintText: 'Išči stranko...',
              hintStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600]!),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF1F7A1F)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setDialogState(() {
                _searchTerm = value;
                _filterCustomers(value);
              });
            },
          ),
          if (_filteredCustomers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1F7A1F)),
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF121212),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = _filteredCustomers[index];
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        _selectedCustomer = customer;
                        _filteredCustomers = [];
                        _searchTerm = '';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: index < _filteredCustomers.length - 1
                            ? const Border(
                                bottom: BorderSide(color: Color(0xFF1F7A1F)),
                              )
                            : null,
                      ),
                      child: Text(
                        '${customer['fullName']} - ${customer['phoneNumber']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
        if (_selectedCustomer != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_selectedCustomer!['fullName']} - ${_selectedCustomer!['phoneNumber']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setDialogState(() {
                      _selectedCustomer = null;
                      _searchTerm = '';
                      _filteredCustomers = [];
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addAppointmentWithCustomer(
    DateTime dateTime,
    Map<String, dynamic> customer,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final appointmentResponse = await http.post(
        Uri.parse('$backendUrl/appointments'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'customerId': customer['_id'],
          'dateFrom': _formatDateWithTimezone(dateTime),
        }),
      );

      if (appointmentResponse.statusCode == 201) {
        final appointmentData = json.decode(appointmentResponse.body);
        final newAppointment = Appointment(
          startTime: _parseDateFromBackend(appointmentData['dateFrom']),
          endTime: _parseDateFromBackend(appointmentData['dateTo']),
          subject: '${customer['fullName']} - ${customer['phoneNumber']}',
          color: Colors.green[700]!,
        );

        setState(() {
          _appointments.add(newAppointment);
          _appointmentIdMap[newAppointment] = appointmentData['_id'];
          _isLoading = false;
          _alertMessage = 'Termin uspešno dodan.';
          _alertColor = Colors.green;
        });
        _showAlert();
      } else {
        throw Exception('Failed to create appointment');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _alertMessage = 'Napaka pri dodajanju termina: ${e.toString()}';
        _alertColor = Colors.red;
      });
      _showAlert();
    }
  }

  void _showAppointmentDetails(Object appointment) {
    final app = appointment as Appointment;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            'Podrobnosti termina',
            style: TextStyle(color: Color(0xFF1F7A1F)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stranka:', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  app.subject,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Datum in čas:',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${app.startTime.day.toString().padLeft(2, '0')}.${app.startTime.month.toString().padLeft(2, '0')}.${app.startTime.year} ob ${app.startTime.hour.toString().padLeft(2, '0')}:${app.startTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zapri', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAppointment(app);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              child: const Text(
                'Izbriši termin',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final appointmentId = _appointmentIdMap[appointment];
    if (appointmentId == null) {
      setState(() {
        _alertMessage = 'Napaka: ID termina ni najden';
        _alertColor = Colors.red;
      });
      _showAlert();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.delete(
        Uri.parse('$backendUrl/appointments/$appointmentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _appointments.remove(appointment);
          _appointmentIdMap.remove(appointment);
          _isLoading = false;
          _alertMessage = 'Termin uspešno izbrisan.';
          _alertColor = Colors.green;
        });
        _showAlert();
      } else {
        throw Exception('Failed to delete appointment');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _alertMessage = 'Napaka pri brisanju termina: ${e.toString()}';
        _alertColor = Colors.red;
      });
      _showAlert();
    }
  }

  void _navigateDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
      _calendarController.selectedDate = _selectedDate;
      _calendarController.displayDate = _selectedDate;
    });
    _fetchAppointments();
  }

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CustomersScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Termini', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _navigateDate(-1),
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _navigateDate(-7),
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          label: const Text('7'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _navigateDate(7),
                          icon: const Text('7'),
                          label: const Icon(Icons.arrow_forward_ios, size: 16),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _navigateDate(1),
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: SfCalendar(
                    view: CalendarView.day,
                    controller: _calendarController,
                    dataSource: _AppointmentDataSource(_appointments),
                    timeSlotViewSettings: const TimeSlotViewSettings(
                      startHour: 6,
                      endHour: 24,
                      timeInterval: Duration(minutes: 20),
                      timeFormat: 'H.mm',
                      timeTextStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    headerStyle: const CalendarHeaderStyle(
                      textStyle: TextStyle(color: Colors.white, fontSize: 18),
                      backgroundColor: Colors.black,
                    ),
                    viewHeaderStyle: const ViewHeaderStyle(
                      dayTextStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      dateTextStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: Colors.black,
                    ),
                    backgroundColor: Colors.black,
                    cellBorderColor: Colors.grey[800],
                    todayHighlightColor: Colors.green[700],
                    selectionDecoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.green[700]!, width: 2),
                    ),
                    onTap: _onCalendarTapped,
                    appointmentBuilder: (context, details) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.green[700],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          details.appointments.first.subject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F7A1F)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Customers'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green[700],
        backgroundColor: Colors.black,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
