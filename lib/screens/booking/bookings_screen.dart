import 'package:flutter/material.dart';
import '../../storage/booking_storage.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: FutureBuilder(
        future: BookingStorage.all(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data as List<Map<String, dynamic>>;
          if (bookings.isEmpty) {
            return const Center(child: Text("No bookings yet"));
          }

          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (_, i) {
              final b = bookings[i];
              return ListTile(
                title: Text(b['booking_code']),
                subtitle: Text("${b['service_type']} • ${b['payment']}"),
              );
            },
          );
        },
      ),
    );
  }
}
