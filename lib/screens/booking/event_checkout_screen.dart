import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

class EventCheckoutScreen extends StatefulWidget {
  final int eventId;
  final DateTime selectedDate;
  final Map<String, int> ticketCounts;
  final List<Map<String, dynamic>> allTicketTypes;

  EventCheckoutScreen({
    Key? key,
    required this.eventId,
    required this.selectedDate,
    required this.ticketCounts,
    required this.allTicketTypes,
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

  bool _submitting = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  // ===========================================================================
  // FINAL EVENT OFFLINE CHECKOUT FLOW
  // ===========================================================================

  Future<void> _confirmBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('Please login to continue');
      }

      // -----------------------------------------------------------------------
      // STEP 1: ADD TO CART (EVENT)
      // -----------------------------------------------------------------------

      final Map<String, String> cartBody = {
        'service_id': widget.eventId.toString(),
        'service_type': 'event',
        'start_date':
            DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      };

      int index = 0;
      widget.ticketCounts.forEach((code, count) {
        if (count > 0) {
          final ticket = widget.allTicketTypes
              .firstWhere((t) => t['code'] == code);

          cartBody['ticket_types[$index][code]'] = code;
          cartBody['ticket_types[$index][number]'] = count.toString();
          cartBody['ticket_types[$index][price]'] =
              ticket['price'].toString();
          index++;
        }
      });

      if (index == 0) {
        throw Exception('Please select at least one ticket');
      }

      final encodedCartBody = cartBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final cartRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/addToCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: encodedCartBody,
      );

      final cartData = jsonDecode(cartRes.body);

      if (cartRes.statusCode != 200 ||
          (cartData['status'] != 1 &&
              cartData['status'] != true)) {
        throw Exception(cartData['message'] ?? 'Add to cart failed');
      }

      final bookingCode = cartData['booking_code'];
      if (bookingCode == null) {
        throw Exception('Booking code missing');
      }

      // -----------------------------------------------------------------------
      // STEP 2: DO CHECKOUT (OFFLINE – EVENT)
      // -----------------------------------------------------------------------

      final checkoutBody = {
      'booking_code': bookingCode,
      'object_model': 'event',

      // User-provided fields (already in UI)
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),

      // 🔥 REQUIRED BY EVENT BACKEND (PLACEHOLDERS)
      'address_line_1': 'N/A',
      'city': 'N/A',
      'country': 'VN',
      'zip_code': '00000',

      // Payment
      'payment_gateway': 'offline',
      'term_conditions': 'on',
    };


      final encodedCheckoutBody = checkoutBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final checkoutRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/doCheckout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: encodedCheckoutBody,
      );

      final checkoutData = jsonDecode(checkoutRes.body);

      if (checkoutRes.statusCode != 200 ||
          (checkoutData['status'] != 1 &&
              checkoutData['status'] != true &&
              checkoutData['booking_code'] == null)) {
        throw Exception(checkoutData['message'] ?? 'Checkout failed');
      }

      // -----------------------------------------------------------------------
      // SUCCESS
      // -----------------------------------------------------------------------

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              bookingCode:
                  checkoutData['booking_code'] ?? bookingCode,
            ),
          ),
        );
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.eventCheckout)),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_firstName, 'First Name'),
              _field(_lastName, 'Last Name'),
              _field(_email, 'Email',
                  type: TextInputType.emailAddress),
              _field(_phone, 'Phone',
                  type: TextInputType.phone),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _submitting ? null : _confirmBooking,
                  child: _submitting
                      ? CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : Text(context.l10n.confirmBooking1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: (v) =>
            v == null || v.isEmpty ? '$label is required' : null,
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}

// ============================================================================
// SUCCESS SCREEN
// ============================================================================

class BookingSuccessScreen extends StatelessWidget {
  final String bookingCode;

  BookingSuccessScreen({Key? key, required this.bookingCode})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.success)),
      body: Center(
        child: Text(
          'Booking Code:\n$bookingCode',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
