import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'booking_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  int _selectedIndex = 1;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _fetchCustomers();
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

  Future<void> _fetchCustomers() async {
    setState(() => _loading = true);
    try {
      final response = await Uri.parse(
        'http://192.168.0.25:3210/api/customers',
      ).resolveUri(Uri());
      final res = await Future.delayed(Duration(milliseconds: 100), () async {
        return await http.get(
          Uri.parse('http://192.168.0.25:3210/api/customers'),
        );
      });
      if (res.statusCode == 200) {
        final List<dynamic> data = List<Map<String, dynamic>>.from(
          json.decode(res.body),
        );
        setState(() {
          _customers = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      // handle error
    }
    setState(() => _loading = false);
  }

  Future<void> _addCustomer() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('http://192.168.0.25:3210/api/customers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fullName': name, 'phoneNumber': phone}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        _nameController.clear();
        _phoneController.clear();
        await _fetchCustomers();
      }
    } catch (e) {
      // handle error
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteCustomer(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potrditev'),
        content: const Text('Ali ste prepričani, da želite izbrisati stranko?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Prekliči'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Izbriši'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      final res = await http.delete(
        Uri.parse('http://192.168.0.25:3210/api/customers/$id'),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _fetchCustomers();
      }
    } catch (e) {
      // handle error
    }
    setState(() => _loading = false);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const BookingScreen(),
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
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Stranke',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontWeight: FontWeight.bold,
            fontSize: 32,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Ime in priimek',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Telefonska številka',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _loading ? null : _addCustomer,
                child: const Text(
                  'Dodaj stranko',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                  ? const Center(
                      child: Text(
                        'Ni strank.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        itemCount: _customers.length,
                        itemBuilder: (context, idx) {
                          final customer = _customers[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(
                                '${customer['fullName']} - ${customer['phoneNumber']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                                onPressed: _loading
                                    ? null
                                    : () => _deleteCustomer(
                                        customer['_id'].toString(),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
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
