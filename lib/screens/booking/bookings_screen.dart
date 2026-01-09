import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../storage/booking_storage.dart';
import 'booking_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';

class BookingsScreen extends StatelessWidget {
  BookingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: Text(
          context.l10n.myBookings, 
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: FutureBuilder(
        future: BookingStorage.all(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookings = snapshot.data as List<Map<String, dynamic>>? ?? [];
          
          if (bookings.isEmpty) {
            // Corrected: Pass context to the helper method
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final b = bookings[i];
              return _buildBookingCard(context, b);
            },
          );
        },
      ),
    );
  }

  // Corrected: Added BuildContext context parameter
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.airplane_ticket_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            context.l10n.noBookingsYet, 
            style: TextStyle(color: Colors.grey[500], fontSize: 16)
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> b) {
    // 1. Detect Service Type
    final String type = (b['service_type'] ?? 'tour').toString().toLowerCase();
    
    // 2. Configure Icon & Color based on Type
    IconData icon;
    Color accentColor;
    String typeLabel;

    if (type.contains('hotel')) {
      icon = Icons.hotel_rounded;
      accentColor = const Color(0xFFFA824C); // Orange
      typeLabel = "Hotel Stay";
    } else if (type.contains('flight')) {
      icon = Icons.flight_takeoff;
      accentColor = const Color(0xFF0077B6); // Blue
      typeLabel = "Flight Ticket";
    } else {
      icon = Icons.map_outlined;
      accentColor = const Color(0xFF00A896); // Teal
      typeLabel = "Tour Package";
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(
                bookingCode: b['booking_code'] ?? '',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel, 
                      style: TextStyle(
                        fontSize: 12, 
                        color: accentColor, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5
                      )
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['booking_code'] ?? 'Unknown Code',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b['payment'] ?? 'Pending',
                      style: TextStyle(
                        fontSize: 13, 
                        color: Colors.grey[600]
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}