import 'package:flutter/material.dart';
import '../../services/service_api.dart';
import '../../storage/booking_storage.dart';
import 'booking_success_screen.dart';
import '../../services/guest_booking_storage.dart';
import 'package:megatour_app/utils/context_extension.dart';

class CheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String serviceType;

  const CheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.serviceType,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final ServiceApi _api = ServiceApi();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _submitting = false;
  String _paymentMethod = 'offline';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final res = await _api.confirmBooking(
        bookingCode: widget.bookingCode,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        paymentMethod: _paymentMethod,
      );

      setState(() => _submitting = false);

      if (res['status'] == 1) {
      await GuestBookingStorage.saveBooking(
        bookingCode: widget.bookingCode,
        serviceType: widget.serviceType,
        serviceName: res['service_title'] ?? 'Booking',
        startDate: res['start_date'] ?? '',
        endDate: res['end_date'] ?? '',
        total: res['total_formatted'] ?? '',
        imageUrl: res['service_icon'],
      );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingSuccessScreen(
              bookingCode: widget.bookingCode,
            ),
          ),
        );
      } else {
        _snack(res['message'] ?? 'Checkout failed');
      }
    } catch (e) {
      setState(() => _submitting = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guest Checkout")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _field(_firstName, "First name"),
              _field(_lastName, "Last name"),
              _field(_email, "Email", TextInputType.emailAddress),
              _field(_phone, "Phone", TextInputType.phone),

              const SizedBox(height: 16),
              const Text("Payment Method",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              RadioListTile(
                value: 'offline',
                groupValue: _paymentMethod,
                title: const Text("Pay later (Offline)"),
                onChanged: (v) => setState(() => _paymentMethod = v.toString()),
              ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CONFIRM BOOKING"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        validator: (v) => v == null || v.isEmpty ? "$label required" : null,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
