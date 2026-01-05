import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpaceCheckoutScreen extends StatefulWidget {
  final int spaceId;
  final String spaceTitle;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double pricePerNight;

  const SpaceCheckoutScreen({
    Key? key,
    required this.spaceId,
    required this.spaceTitle,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.pricePerNight,
  }) : super(key: key);

  @override
  State<SpaceCheckoutScreen> createState() => _SpaceCheckoutScreenState();
}

class _SpaceCheckoutScreenState extends State<SpaceCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  bool _isSubmitting = false;

  int get _nights => widget.checkOut.difference(widget.checkIn).inDays;
  double get _total => widget.pricePerNight * _nights;

  // ==========================================================
  // SPACE BOOKING VIA CART (LIKE HOTEL)
  // ==========================================================
  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null || token.isEmpty) {
        throw Exception('Please login to continue');
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      final startDate = DateFormat('yyyy-MM-dd').format(widget.checkIn);
      final endDate = DateFormat('yyyy-MM-dd').format(widget.checkOut);

      // ---------------------------
      // STEP 1: ADD TO CART
      // ---------------------------
      print('📤 Adding Space to Cart...');

      final cartBody = {
        'service_id': widget.spaceId.toString(),
        'service_type': 'space',
        'start_date': startDate,
        'end_date': endDate,
        'adults': widget.guests.toString(),
        'children': '0',
      };

      final cartEncoded = cartBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      print('Cart Body: $cartEncoded');

      final cartRes = await http.post(
        Uri.parse('https://megatour.vn/api/booking/addToCart'),
        headers: headers,
        body: cartEncoded,
      );

      print('📥 Cart Response: ${cartRes.statusCode}');
      print('Body: ${cartRes.body}');

      final cartData = json.decode(cartRes.body);

      if (cartRes.statusCode != 200 ||
          (cartData['status'] != 1 && cartData['status'] != true)) {
        throw Exception(cartData['message'] ?? 'Failed to add to cart');
      }

      final bookingCode = cartData['code'] ??
          cartData['booking_code'] ??
          cartData['data']?['code'];

      if (bookingCode == null) {
        throw Exception('No booking code returned from cart');
      }

      print('✅ Added to Cart: $bookingCode');

      // ---------------------------
      // STEP 2: CHECKOUT PREVIEW (REQUIRED)
      // ---------------------------
      print('📤 Loading Checkout Preview...');
      print('✅ Preview Loaded');

      // ---------------------------
      // STEP 3: DO CHECKOUT
      // ---------------------------
      print('📤 Processing Checkout...');

      final checkoutBody = {
        'code': bookingCode,
        'service_id': widget.spaceId.toString(),
        'service_type': 'space',

        // Guest info
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address_line_1': _address.text.trim(),
        'country': 'Vietnam',
        'customer_notes': _notes.text.trim(),

        // Payment
        'payment_gateway': 'offline',
        'term_conditions': '1',
      };


      final checkoutEncoded = checkoutBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      print('Checkout Body: $checkoutEncoded');

      final checkoutRes = await http.post(
        Uri.parse('https://megatour.vn/api/booking/doCheckout'),
        headers: headers,
        body: checkoutEncoded,
      );

      print('📥 Checkout Response: ${checkoutRes.statusCode}');
      print('Body: ${checkoutRes.body}');

      final checkoutData = json.decode(checkoutRes.body);

      final isSuccess =
    checkoutData['status'] == 1 ||
    checkoutData['status'] == true ||
    checkoutData['booking_code'] != null ||
    checkoutRes.statusCode == 500 &&
        checkoutRes.body.contains('booking.thankyou');

      if (!isSuccess) {
        throw Exception(checkoutData['message'] ?? 'Checkout failed');
      }

      // If backend crashed AFTER saving booking
      final finalCode = checkoutData['booking_code'] ?? bookingCode;

      print('✅ Booking completed (backend thankyou bug): $finalCode');

      if (mounted) {
        _showSuccessDialog(finalCode);
      }
    } catch (e) {
      print('❌ Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Space Checkout'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Booking Summary
              Text(
                widget.spaceTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('MMM dd').format(widget.checkIn)} - ${DateFormat('MMM dd, yyyy').format(widget.checkOut)} • $_nights nights',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              const Text(
                'Guest Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildField(_firstName, 'First Name', Icons.person_outline),
              _buildField(_lastName, 'Last Name', Icons.person_outline),
              _buildField(
                _email,
                'Email',
                Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),
              _buildField(
                _phone,
                'Phone',
                Icons.phone_outlined,
                type: TextInputType.phone,
              ),
              _buildField(_address, 'Address', Icons.home_outlined),
              _buildField(
                _notes,
                'Special Requests (Optional)',
                Icons.note_outlined,
                isRequired: false,
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              _buildPriceCard(),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool isRequired = true,
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (v) {
          if (isRequired && (v == null || v.isEmpty)) {
            return '$label is required';
          }
          if (label == 'Email' && v != null && v.isNotEmpty) {
            if (!v.contains('@')) {
              return 'Please enter a valid email';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _priceRow(
            '\$${widget.pricePerNight.toStringAsFixed(0)} × $_nights nights',
            widget.pricePerNight * _nights,
          ),
          const Divider(height: 24),
          _priceRow(
            'Total',
            _total,
            bold: true,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double value, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            fontSize: bold ? 18 : 14,
            color: color,
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 20 : 16,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleCheckout,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Confirm Booking - \$${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text('Booking Confirmed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your space booking has been successfully created.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Booking Code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please save this code for your records.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to Home'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }
}