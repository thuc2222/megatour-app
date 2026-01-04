// lib/screens/booking/event_checkout_screen.dart
// Guest checkout with email notification option

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/guest_booking_storage.dart';
import 'booking_success_screen.dart';

class EventCheckoutScreen extends StatefulWidget {
  final int eventId;
  final DateTime selectedDate;
  final Map<String, int> ticketCounts;
  final Map<String, int> extraCounts;

  const EventCheckoutScreen({
    Key? key,
    required this.eventId,
    required this.selectedDate,
    required this.ticketCounts,
    required this.extraCounts,
  }) : super(key: key);

  @override
  State<EventCheckoutScreen> createState() => _EventCheckoutScreenState();
}

class _EventCheckoutScreenState extends State<EventCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  bool _submitting = false;
  String _paymentMethod = 'offline_payment';
  bool _acceptTerms = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CALCULATE TOTAL
  // ---------------------------------------------------------------------------

  double _calculateTotal() {
    double total = 0;
    
    widget.ticketCounts.forEach((code, count) {
      // In real app, get actual prices from event detail API
      total += count * 100;
    });

    widget.extraCounts.forEach((name, count) {
      total += count * 50;
    });

    return total;
  }

  // ---------------------------------------------------------------------------
  // CREATE GUEST BOOKING
  // ---------------------------------------------------------------------------

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _snack('Please accept terms and conditions', Colors.orange);
      return;
    }

    setState(() => _submitting = true);

    try {
      // Generate booking code
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bookingCode = 'EVT$timestamp';

      final startDate = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      final endDate = DateFormat('yyyy-MM-dd').format(
        widget.selectedDate.add(const Duration(days: 1)),
      );

      // Build booking details
      final bookingDetails = _buildBookingDetails(bookingCode, startDate, endDate);

      // Save locally
      await GuestBookingStorage.saveBooking(
        bookingCode: bookingCode,
        serviceType: 'event',
        serviceName: bookingDetails['ticket_summary'],
        startDate: startDate,
        endDate: endDate,
        total: '\$${_calculateTotal().toStringAsFixed(2)}',
      );

      // Attempt to send email notification to venue
      final emailSent = await _sendEmailNotification(bookingDetails);

      setState(() => _submitting = false);

      if (!mounted) return;

      // Show success message
      _showSuccessDialog(bookingCode, emailSent);

    } catch (e) {
      debugPrint('❌ Booking error: $e');
      setState(() => _submitting = false);
      _snack('Error creating booking. Please try again.', Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD BOOKING DETAILS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildBookingDetails(String bookingCode, String startDate, String endDate) {
    // Build ticket summary
    String ticketSummary = '';
    List<Map<String, dynamic>> tickets = [];
    
    widget.ticketCounts.forEach((code, count) {
      if (count > 0) {
        final name = code.replaceAll('_', ' ').toUpperCase();
        ticketSummary += '$count x $name\n';
        tickets.add({
          'type': name,
          'quantity': count,
          'price': 100, // placeholder
        });
      }
    });

    // Build extras
    List<Map<String, dynamic>> extras = [];
    widget.extraCounts.forEach((name, count) {
      if (count > 0) {
        extras.add({
          'name': name,
          'quantity': count,
          'price': 50, // placeholder
        });
      }
    });

    return {
      'booking_code': bookingCode,
      'event_id': widget.eventId,
      'event_date': startDate,
      'end_date': endDate,
      'ticket_summary': ticketSummary.trim(),
      'tickets': tickets,
      'extras': extras,
      'customer': {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
      },
      'payment_method': _paymentMethod,
      'total': _calculateTotal(),
      'notes': _notes.text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // SEND EMAIL NOTIFICATION (OPTIONAL)
  // ---------------------------------------------------------------------------

  Future<bool> _sendEmailNotification(Map<String, dynamic> bookingDetails) async {
    try {
      // You can use a service like EmailJS, SendGrid API, or your own backend
      // For now, we'll simulate sending email
      
      debugPrint('📧 Attempting to send email notification...');
      debugPrint('Booking details: ${json.encode(bookingDetails)}');

      // Example: Using a webhook or email service
      // final response = await http.post(
      //   Uri.parse('YOUR_WEBHOOK_OR_EMAIL_API'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode(bookingDetails),
      // );

      // return response.statusCode == 200;

      // For now, return false (email not sent)
      await Future.delayed(const Duration(seconds: 1));
      return false;

    } catch (e) {
      debugPrint('❌ Email notification failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SUCCESS DIALOG
  // ---------------------------------------------------------------------------

  void _showSuccessDialog(String bookingCode, bool emailSent) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Created!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Booking Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    bookingCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Important',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emailSent
                        ? '• Confirmation sent to ${_email.text}\n• Show this code at the venue\n• Save this booking code'
                        : '• Please save this booking code\n• Show it at the venue entrance\n• Contact venue to confirm: ${_phone.text}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Share booking code
                      _shareBookingCode(bookingCode);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingSuccessScreen(
                            bookingCode: bookingCode,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareBookingCode(String code) {
    // In a real app, use share_plus package
    // Share.share('My event booking code: $code');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking code copied: $code'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Guest Checkout'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // INFO BANNER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.blue.shade50],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.purple.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Guest Booking',
                          style: TextStyle(
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No account needed • Instant booking code • Show at venue',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // BOOKING SUMMARY
            _buildSummaryCard(),
            const SizedBox(height: 20),

            // CUSTOMER INFO
            const Text(
              'Your Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(_firstName, 'First Name *', Icons.person)),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(_lastName, 'Last Name *', Icons.person)),
              ],
            ),
            _buildTextField(_email, 'Email *', Icons.email,
                type: TextInputType.emailAddress),
            _buildTextField(_phone, 'Phone *', Icons.phone,
                type: TextInputType.phone),
            _buildTextField(_notes, 'Special Requests', Icons.note,
                required: false, maxLines: 3),

            const SizedBox(height: 24),

            // PAYMENT METHOD
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  RadioListTile(
                    value: 'offline_payment',
                    groupValue: _paymentMethod,
                    title: const Text('Pay at Venue'),
                    subtitle: const Text('Cash or card at entrance'),
                    onChanged: (v) => setState(() => _paymentMethod = v.toString()),
                  ),
                  Divider(height: 1, color: Colors.grey.shade300),
                  RadioListTile(
                    value: 'bank_transfer',
                    groupValue: _paymentMethod,
                    title: const Text('Bank Transfer'),
                    subtitle: const Text('Transfer before event'),
                    onChanged: (v) => setState(() => _paymentMethod = v.toString()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // TERMS
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              title: const Text(
                'I accept the terms and conditions',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                'By booking, you agree to pay at venue or via selected method',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            // CONFIRM BUTTON
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _submitting ? null : _createBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.confirmation_number, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                'Booking Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _summaryRow(
            'Event Date',
            DateFormat('EEEE, MMM dd, yyyy').format(widget.selectedDate),
            icon: Icons.calendar_today,
          ),

          const Divider(height: 24),

          const Text(
            'Tickets',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 8),
          ...widget.ticketCounts.entries.where((e) => e.value > 0).map(
                (entry) => _summaryRow(
                  entry.key.replaceAll('_', ' ').toUpperCase(),
                  '${entry.value}x',
                ),
              ),

          if (widget.extraCounts.values.any((c) => c > 0)) ...[
            const Divider(height: 24),
            const Text(
              'Extra Services',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...widget.extraCounts.entries.where((e) => e.value > 0).map(
                  (entry) => _summaryRow(entry.key, '${entry.value}x'),
                ),
          ],

          const Divider(height: 24),

          _summaryRow(
            'Total Amount',
            '\$${_calculateTotal().toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14,
                  color: bold ? Colors.black : Colors.grey[700],
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 18 : 14,
              color: bold ? const Color(0xFF6C5CE7) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.isEmpty) return '${label.replaceAll('*', '').trim()} required';
          if (label.contains('Email') && !v.contains('@')) return 'Invalid email';
          return null;
        },
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}