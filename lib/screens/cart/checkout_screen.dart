import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:megatour_app/utils/context_extension.dart';

class CheckoutScreen extends StatefulWidget {
  CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _gateways = [];
  String? _selectedGateway;

  // Form Controllers
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGateways();
  }

  Future<void> _fetchGateways() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gateways'),
        headers: ApiConfig.getHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> allGateways = json.decode(response.body);
        setState(() {
          // Filtering for Offline methods (usually 'offline_payment' or 'bank_transfer')
          _gateways = allGateways.where((g) => 
            g['id'] == 'offline_payment' || g['id'] == 'bank_transfer'
          ).toList();

          // If no specific offline tag found, show all so the user can pick
          if (_gateways.isEmpty) _gateways = allGateways;

          if (_gateways.isNotEmpty) _selectedGateway = _gateways[0]['id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error loading payment methods", Colors.red);
    }
  }

  Future<void> _doCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGateway == null) {
      _showSnackBar("Please select a payment method", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/booking/doCheckout'),
        headers: ApiConfig.getHeaders(),
        body: json.encode({
          "first_name": _firstName.text,
          "last_name": _lastName.text,
          "email": _email.text,
          "phone": _phone.text,
          "address_line_1": _address.text,
          "payment_gateway": _selectedGateway,
          "term_conditions": "on"
        }),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200) {
        if (result['status'] == 1 || result['booking_code'] != null) {
          _showSuccessDialog(result['booking_code'] ?? "");
        } else {
          _showSnackBar(result['message'] ?? "Checkout failed", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 10),
            Text(context.l10n.bookingReceived),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.yourBookingIsPendingConfirmation, textAlign: TextAlign.center),
            SizedBox(height: 15),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text("Code: $code", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
            ),
            SizedBox(height: 10),
            Text(context.l10n.pleaseCheckYourEmailForPaymentInstructions, style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(context.l10n.backToHome),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkout1), elevation: 0),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.customerDetails, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    _buildField(_firstName, "First Name", Icons.person_outline),
                    _buildField(_lastName, "Last Name", Icons.person_outline),
                    _buildField(_email, "Email Address", Icons.email_outlined, type: TextInputType.emailAddress),
                    _buildField(_phone, "Phone Number", Icons.phone_android, type: TextInputType.phone),
                    _buildField(_address, "Full Address", Icons.map_outlined),
                    
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(context.l10n.offlinePaymentMethod, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Column(
                        children: _gateways.map((g) => RadioListTile(
                          activeColor: Colors.blue,
                          title: Text(g['name'] ?? "Payment Method"),
                          subtitle: Text(g['desc'] ?? "Pay via bank transfer or at arrival"),
                          value: g['id'].toString(),
                          groupValue: _selectedGateway,
                          onChanged: (val) => setState(() => _selectedGateway = val as String),
                        )).toList(),
                      ),
                    ),

                    SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _doCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting 
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(context.l10n.completeBooking, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (v) => v!.isEmpty ? "Required field" : null,
      ),
    );
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
}