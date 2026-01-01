import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../booking/booking_detail_screen.dart';

const String API_BASE_URL = 'https://megatour.vn/api/';

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  late Future<List<BookingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBookings();
  }

  Future<List<BookingItem>> _loadBookings() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null) return [];

    final res = await http.get(
      Uri.parse('${API_BASE_URL}user/booking-history'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${auth.token}',
      },
    );

    if (res.statusCode != 200) return [];

    final decoded = jsonDecode(res.body);
    final List data = decoded['data'] ?? [];

    return data.map((e) => BookingItem.fromJson(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return const Center(
        child: Text('Login to view your bookings'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<BookingItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(
              child: Text(
                'No bookings yet',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return BookingCard(item: bookings[index]);
            },
          );
        },
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// BOOKING CARD (CLICKABLE → BOOKING DETAIL)
/// ---------------------------------------------------------------------------

class BookingCard extends StatelessWidget {
  final BookingItem item;

  const BookingCard({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingDetailScreen(
              bookingCode: item.bookingCode,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: _statusGradient(item.status),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : _imagePlaceholder(),
            ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _serviceTypeChip(item.objectModel),
                  const SizedBox(height: 10),
                  Text(
                    item.serviceName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.dateRange,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.totalFormatted,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2C5364), Color(0xFF203A43)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white54, size: 48),
      ),
    );
  }

  Widget _serviceTypeChip(String type) {
    final icons = {
      'hotel': Icons.hotel,
      'tour': Icons.map,
      'car': Icons.directions_car,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[type] ?? Icons.travel_explore,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            type.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// HELPERS
/// ---------------------------------------------------------------------------

LinearGradient _statusGradient(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
    case 'paid':
      return const LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      );
    case 'draft':
    case 'pending':
      return const LinearGradient(
        colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
      );
    case 'cancelled':
      return const LinearGradient(
        colors: [Color(0xFFCB356B), Color(0xFFBD3F32)],
      );
    default:
      return const LinearGradient(
        colors: [Color(0xFF396AFC), Color(0xFF2948FF)],
      );
  }
}

/// ---------------------------------------------------------------------------
/// DATA MODEL
/// ---------------------------------------------------------------------------

class BookingItem {
  final String bookingCode;
  final String objectModel;
  final String serviceName;
  final String status;
  final String dateRange;
  final String totalFormatted;
  final String? imageUrl;

  BookingItem({
    required this.bookingCode,
    required this.objectModel,
    required this.serviceName,
    required this.status,
    required this.dateRange,
    required this.totalFormatted,
    this.imageUrl,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>?;

    return BookingItem(
      bookingCode: json['code'] ?? '',
      objectModel: json['object_model'] ?? 'other',
      serviceName:
          service?['title'] ??
          json['service_title'] ??
          'Booking',
      status: json['status'] ?? 'draft',
      dateRange:
          '${json['start_date'] ?? ''} → ${json['end_date'] ?? ''}',
      totalFormatted:
          json['total_formatted'] ?? '${json['total'] ?? 0}',
      imageUrl: service?['image'],
    );
  }
}
