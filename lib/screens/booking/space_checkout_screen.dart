// lib/screens/booking/space_checkout_screen.dart
// Guest checkout for space bookings with offline payment

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/guest_booking_storage.dart';
import 'booking_success_screen.dart';

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

  bool _submitting = false;
  String _paymentMethod = 'offline';
  bool _acceptTerms = true;

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

  int get _nights => widget.checkOut.difference(widget.checkIn).inDays;
  double get _subtotal => widget.pricePerNight * _nights;
  double get _cleaningFee => 100;
  double get _serviceFee => 200;
  double get _total => _subtotal + _cleaningFee + _serviceFee;

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
      final bookingCode = 'SPC$timestamp';

      final startDate = DateFormat('yyyy-MM-dd').format(widget.checkIn);
      final endDate = DateFormat('yyyy-MM-dd').format(widget.checkOut);

      // Save locally
      await GuestBookingStorage.saveBooking(
        bookingCode: bookingCode,
        serviceType: 'space',
        serviceName: widget.spaceTitle,
        startDate: startDate,
        endDate: endDate,
        total: '\$${_total.toStringAsFixed(2)}',
      );

      setState(() => _submitting = false);

      if (!mounted) return;

      // Show success dialog
      _showSuccessDialog(bookingCode);

    } catch (e) {
      debugPrint('❌ Booking error: $e');
      setState(() => _submitting = false);
      _snack('Error creating booking. Please try again.', Colors.red);
    }
  }

  void _showSuccessDialog(String bookingCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Reservation Confirmed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Booking Code',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B9D).withOpacity(0.1),
                    const Color(0xFFC06FFE).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B9D).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Important',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Confirmation sent to ${_email.text}\n'
                    '• Show this code at check-in\n'
                    '• Payment due: ${_paymentMethod == 'offline' ? 'At property' : 'Via bank transfer'}',
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: const Center(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Confirm and pay'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // TRIP DETAILS
            _buildTripCard(),
            const SizedBox(height: 20),

            // CUSTOMER INFO
            _buildSection(
              'Your information',
              [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _firstName,
                        'First name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        _lastName,
                        'Last name',
                        Icons.person_outline,
                      ),
                    ),
                  ],
                ),
                _buildTextField(_email, 'Email', Icons.email_outlined,
                    type: TextInputType.emailAddress),
                _buildTextField(_phone, 'Phone', Icons.phone_outlined,
                    type: TextInputType.phone),
                _buildTextField(_address, 'Address', Icons.location_on_outlined,
                    required: false),
                _buildTextField(_notes, 'Special requests', Icons.note_outlined,
                    required: false, maxLines: 3),
              ],
            ),

            const SizedBox(height: 20),

            // PRICE BREAKDOWN
            _buildPriceCard(),

            const SizedBox(height: 20),

            // PAYMENT METHOD
            _buildSection(
              'Payment method',
              [
                _buildPaymentOption(
                  'offline',
                  'Pay at property',
                  'Cash or card accepted',
                  Icons.home_outlined,
                ),
                _buildPaymentOption(
                  'bank_transfer',
                  'Bank transfer',
                  'Transfer before check-in',
                  Icons.account_balance_outlined,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // TERMS
            CheckboxListTile(
              value: _acceptTerms,
              onChanged: (v) => setState(() => _acceptTerms = v ?? false),
              title: const Text(
                'I agree to the terms and conditions',
                style: TextStyle(fontSize: 14),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 24),

            // RESERVE BUTTON
            SizedBox(
              height: 54,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitting ? null : _createBooking,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirm reservation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard() {
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
          const Text(
            'Your trip',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _infoRow('Dates', '${DateFormat('MMM dd').format(widget.checkIn)} - ${DateFormat('MMM dd, yyyy').format(widget.checkOut)}'),
          _infoRow('Guests', '${widget.guests} guest${widget.guests > 1 ? 's' : ''}'),
          _infoRow('Nights', '$_nights night${_nights > 1 ? 's' : ''}'),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
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
          const Text(
            'Price details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _priceRow('\$${widget.pricePerNight.toStringAsFixed(0)} x $_nights nights', '\$${_subtotal.toStringAsFixed(2)}'),
          _priceRow('Cleaning fee', '\$${_cleaningFee.toStringAsFixed(2)}'),
          _priceRow('Service fee', '\$${_serviceFee.toStringAsFixed(2)}'),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                ).createShader(bounds),
                child: Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
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
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _paymentMethod == value
              ? const Color(0xFFFF6B9D)
              : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RadioListTile(
        value: value,
        groupValue: _paymentMethod,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        secondary: Icon(icon),
        onChanged: (v) => setState(() => _paymentMethod = v.toString()),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (v) {
          if (!required) return null;
          if (v == null || v.isEmpty) return '$label required';
          if (label == 'Email' && !v.contains('@')) return 'Invalid email';
          return null;
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
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