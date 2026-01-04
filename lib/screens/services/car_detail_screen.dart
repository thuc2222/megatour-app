// lib/screens/services/car_detail_screen.dart
// Modern car detail with REAL booking (API) – UI unchanged

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../booking/booking_success_screen.dart';

class CarDetailScreen extends StatefulWidget {
  final int carId;

  const CarDetailScreen({Key? key, required this.carId}) : super(key: key);

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  DateTime? _pickupDate;
  DateTime? _returnDate;

  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _showBooking = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _fetchCarDetail();
  }

  Future<Map<String, dynamic>> _fetchCarDetail() async {
    final res = await http.get(
      Uri.parse('https://megatour.vn/api/car/detail/${widget.carId}'),
    );

    if (res.statusCode != 200) throw Exception('Failed to load car');
    return json.decode(res.body)['data'];
  }

  int get _days {
    if (_pickupDate == null || _returnDate == null) return 0;
    return _returnDate!.difference(_pickupDate!).inDays;
  }

  double _calculateTotal(String? price) {
    if (_days == 0) return 0;
    final p = double.tryParse(price ?? '0') ?? 0;
    return (p * _days) + 100 + 200;
  }

  // --------------------------------------------------
  // REAL BOOKING FLOW
  // --------------------------------------------------

  Future<void> _createBooking(Map<String, dynamic> car) async {
  if (!_formKey.currentState!.validate()) return;

  final auth = context.read<AuthProvider>();
  final token = auth.token;

  // ✅ CHECK LOGIN FIRST
  if (token == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to continue')),
    );
    return;
  }

  setState(() => _submitting = true);

  try {
    final res = await http.post(
      Uri.parse('https://megatour.vn/api/booking/addToCart'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: {
        'service_id': car['id'].toString(),
        'service_type': 'car',
        'start_date': DateFormat('yyyy-MM-dd').format(_pickupDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
        'number': '1',
      },
    );

    final data = json.decode(res.body);

    if (res.statusCode != 200 || data['status'] != 1) {
      throw Exception(data['message'] ?? 'Booking failed');
    }

    // ✅ SUCCESS
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingSuccessScreen(
          bookingCode: data['booking_code'] ?? '',
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.toString())),
    );
  } finally {
    setState(() => _submitting = false);
  }
}


  // --------------------------------------------------
  // UI BELOW — 100% UNCHANGED
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final car = snapshot.data!;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildAppBar(car),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(car),
                        _buildDateSelector(car),
                        _buildSpecs(car),
                        _buildFeatures(car),
                        _buildDescription(car),
                        if (_showBooking) _buildBookingForm(car),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
              _buildBackButton(),
            ],
          );
        },
      ),
      bottomSheet: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return _buildBottomBar(snapshot.data!);
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(Map<String, dynamic> car) {
    return SliverAppBar(
      expandedHeight: 300,
      automaticallyImplyLeading: false,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              car['banner_image'] ?? car['image'] ?? '',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> car) {
    final review = car['review_score'];
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            car['title'] ?? '',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (review != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${review['score_total']} (${review['total_review']} reviews)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(Map<String, dynamic> car) {
    final price = car['sale_price'] ?? car['price'];
    final total = _calculateTotal(price?.toString());
    
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.1),
            const Color(0xFF764ba2).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ).createShader(bounds),
                child: Text(
                  '\$$price',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(' / day', style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dateButton('PICKUP', _pickupDate, () => _selectDate(true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateButton('RETURN', _returnDate, () => _selectDate(false)),
              ),
            ],
          ),
          if (_days > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$$price x $_days days'),
                      Text('\$${((double.tryParse(price.toString()) ?? 0) * _days).toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ).createShader(bounds),
                        child: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date != null ? DateFormat('MMM dd').format(date) : 'Select',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: date != null ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isPickup) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        if (isPickup) {
          _pickupDate = date;
          if (_returnDate != null && _returnDate!.isBefore(date)) {
            _returnDate = date.add(const Duration(days: 1));
          }
        } else {
          _returnDate = date;
        }
      });
    }
  }

  Widget _buildSpecs(Map<String, dynamic> car) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Specifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (car['passenger'] != null)
                _specCard(Icons.person, '${car['passenger']} Passengers'),
              if (car['baggage'] != null)
                _specCard(Icons.luggage, '${car['baggage']} Bags'),
              if (car['transmission_type'] != null)
                _specCard(Icons.settings, car['transmission_type']),
              if (car['gear'] != null)
                _specCard(Icons.speed, car['gear']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specCard(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFeatures(Map<String, dynamic> car) {
    final features = car['features'] as List? ?? [];
    if (features.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Features', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF667eea)),
                    const SizedBox(width: 8),
                    Text(f['name'] ?? ''),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDescription(Map<String, dynamic> car) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          HtmlWidget(car['content'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildBookingForm(Map<String, dynamic> car) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _textField(_firstName, 'First name', Icons.person)),
                const SizedBox(width: 12),
                Expanded(child: _textField(_lastName, 'Last name', Icons.person)),
              ],
            ),
            _textField(_email, 'Email', Icons.email, TextInputType.emailAddress),
            _textField(_phone, 'Phone', Icons.phone, TextInputType.phone),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitting ? null : () => _createBooking(car),
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: _submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Confirm Rental',
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
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, IconData icon, [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return '$label required';
          if (label == 'Email' && !v.contains('@')) return 'Invalid email';
          return null;
        },
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic> car) {
    final canBook = _pickupDate != null && _returnDate != null && _days > 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: canBook
                  ? const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])
                  : null,
              color: canBook ? null : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canBook
                    ? () => setState(() => _showBooking = true)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    canBook ? 'Book Now' : 'Select dates to continue',
                    style: const TextStyle(
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
      ),
    );
  }
}