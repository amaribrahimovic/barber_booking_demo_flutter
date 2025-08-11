import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/customers_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barber Booking Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/booking': (context) => const BookingScreen(),
        '/customers': (context) => const CustomersScreen(),
      },
    );
  }
}
