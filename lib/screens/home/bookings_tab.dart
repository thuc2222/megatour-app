// lib/screens/home/bookings_tab.dart
import 'package:flutter/material.dart';

class BookingsTab extends StatelessWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
      ),
      body: const Center(
        child: Text('Bookings Tab - Will be implemented'),
      ),
    );
  }
}