// lib/screens/booking/booking_detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingCode;

  const BookingDetailScreen({
    Key? key,
    required this.bookingCode,
  }) : super(key: key);

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _booking;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null) {
      setState(() {
        _error = 'Please login to continue';
        _loading = false;
      });
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(
          'https://megatour.vn/api/booking/${widget.bookingCode}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final body = json.decode(res.body);

      if (res.statusCode != 200 || body['status'] != 1) {
        throw Exception(body['message'] ?? 'Failed to load booking');
      }

      setState(() {
        _booking = body['data'];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final b = _booking!;
    final df = DateFormat('yyyy-MM-dd');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _section(
          title: 'Booking Info',
          children: [
            _row('Code', b['code']),
            _row('Status', b['status']),
            _row('Service', b['object_model']),
            _row('Service ID', b['object_id'].toString()),
          ],
        ),
        _section(
          title: 'Date',
          children: [
            _row('Start', df.format(DateTime.parse(b['start_date']))),
            _row('End', df.format(DateTime.parse(b['end_date']))),
          ],
        ),
        _section(
          title: 'Guest',
          children: [
            _row('Name', '${b['first_name']} ${b['last_name']}'),
            _row('Email', b['email']),
            _row('Phone', b['phone']),
            _row('Guests', b['total_guests'].toString()),
          ],
        ),
        _section(
          title: 'Payment',
          children: [
            _row('Total', '\$${b['total']}'),
            _row('Paid', '\$${b['paid'] ?? 0}'),
            _row('Pay Now', '\$${b['pay_now'] ?? 0}'),
          ],
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
