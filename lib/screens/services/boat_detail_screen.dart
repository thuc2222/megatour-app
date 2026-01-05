import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class BoatDetailScreen extends StatefulWidget {
  final int boatId;

  const BoatDetailScreen({
    Key? key,
    required this.boatId,
  }) : super(key: key);

  @override
  State<BoatDetailScreen> createState() => _BoatDetailScreenState();
}

class _BoatDetailScreenState extends State<BoatDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _checking = false;
  bool _submitting = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _adults = 2;
  int _children = 0;

  final PageController _pageController = PageController();
  Timer? _galleryTimer;
  int _currentPage = 0;

  List<dynamic> _availableSlots = [];
  Map<String, dynamic>? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadBoat();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD BOAT DETAIL
  // ---------------------------------------------------------------------------

  Future<void> _loadBoat() async {
    try {
      final res = await http.get(
        Uri.parse('https://megatour.vn/api/boat/detail/${widget.boatId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        setState(() {
          _data = json['data'];
          _loading = false;
        });
        _startAutoSlide();
      }
    } catch (e) {
      setState(() => _loading = false);
      print('Load error: $e');
    }
  }

  void _startAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length < 2) return;

    _galleryTimer?.cancel();
    _galleryTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) return;
        _currentPage = (_currentPage + 1) % gallery.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CHECK AVAILABILITY
  // ---------------------------------------------------------------------------

  Future<void> _checkAvailability() async {
    if (_selectedDate == null) {
      _snack('Please select a date', Colors.orange);
      return;
    }

    setState(() => _checking = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final date = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // ✅ FIX: Boat API requires start_date and start_time
      final res = await http.get(
        Uri.parse(
          'https://megatour.vn/api/boat/availability-booking/${widget.boatId}'
          '?start_date=$date&start_time=00:00&adults=$_adults&children=$_children',
        ),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      print('Availability Response: ${res.statusCode}');
      print('Body: ${res.body}');

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        
        // Check if API returned success
        if (json['status'] == 1 || json['status'] == true) {
          setState(() {
            _availableSlots = json['data'] ?? [];
            _checking = false;
          });

          if (_availableSlots.isEmpty) {
            _snack('No available slots for this date', Colors.orange);
          }
        } else {
          setState(() => _checking = false);
          _snack(json['message']?.toString() ?? 'Failed to check availability', Colors.red);
        }
      } else {
        setState(() => _checking = false);
        _snack('Failed to check availability', Colors.red);
      }
    } catch (e) {
      setState(() => _checking = false);
      print('Availability error: $e');
      _snack('Error checking availability', Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // BOOK NOW
  // ---------------------------------------------------------------------------

  Future<void> _bookNow() async {
    if (_selectedDate == null) {
      _snack('Please select a date', Colors.orange);
      return;
    }

    if (_selectedSlot == null) {
      _snack('Please select a time slot', Colors.orange);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null) {
      _snack('Please login to book', Colors.red);
      Navigator.pushNamed(context, '/login');
      return;
    }

    setState(() => _submitting = true);

    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // STEP 1: ADD TO CART
      print('📤 Adding Boat to Cart...');

      final cartBody = {
        'service_id': widget.boatId.toString(),
        'service_type': 'boat',
        'start_date': date,
        'end_date': date,
        'adults': _adults.toString(),
        'children': _children.toString(),
        'time_slot_id': _selectedSlot!['id'].toString(),
      };

      final cartEncoded = cartBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final cartRes = await http.post(
        Uri.parse('https://megatour.vn/api/booking/addToCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: cartEncoded,
      );

      print('📥 Cart Response: ${cartRes.statusCode}');
      print('Body: ${cartRes.body}');

      final cartData = jsonDecode(cartRes.body);

      if (cartRes.statusCode != 200 ||
          (cartData['status'] != 1 && cartData['status'] != true)) {
        throw Exception(cartData['message'] ?? 'Failed to add to cart');
      }

      final bookingCode = cartData['code'] ??
          cartData['booking_code'] ??
          cartData['data']?['code'];

      if (bookingCode == null) {
        throw Exception('No booking code returned');
      }

      print('✅ Added to Cart: $bookingCode');

      // Navigate to checkout
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BoatCheckoutScreen(
              bookingCode: bookingCode,
              boatTitle: _data?['title'] ?? 'Boat',
              date: _selectedDate!,
              timeSlot: _selectedSlot!,
              adults: _adults,
              children: _children,
              total: _calculateTotal(),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Booking error: $e');
      _snack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  double _calculateTotal() {
    if (_selectedSlot == null) return 0;

    final price = double.tryParse(_selectedSlot!['price']?.toString() ?? '0') ?? 0;
    return price * _adults;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_data == null) {
      return const Scaffold(
        body: Center(child: Text('Boat not found')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildBookingPanel(),
                    if (_availableSlots.isNotEmpty) _buildTimeSlots(),
                    _buildSection(
                      'Description',
                      HtmlWidget(_data!['content'] ?? ''),
                    ),
                    _buildFeatures(),
                    _buildIncluded(),
                    _buildReviews(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          _buildFloatingBookButton(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar() {
    final gallery = _data!['gallery'];

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.blue,
      flexibleSpace: FlexibleSpaceBar(
        background: gallery is List && gallery.isNotEmpty
            ? PageView.builder(
                controller: _pageController,
                itemCount: gallery.length,
                onPageChanged: (i) => _currentPage = i,
                itemBuilder: (_, i) {
                  return Image.network(
                    gallery[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                    ),
                  );
                },
              )
            : Container(color: Colors.grey[300]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final review = _data!['review_score'];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_boat, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'BOAT',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (review != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        review['score_total'].toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _data!['title'] ?? '',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_data!['location'] != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _data!['location']['name'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoChip(
                Icons.people,
                'Max ${_data!['max_guests'] ?? 'N/A'} guests',
              ),
              const SizedBox(width: 12),
              _infoChip(
                Icons.schedule,
                '${_data!['duration'] ?? 'N/A'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKING PANEL
  // ---------------------------------------------------------------------------

  Widget _buildBookingPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Date & Guests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // DATE
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                initialDate: _selectedDate ?? DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                  _availableSlots = [];
                  _selectedSlot = null;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate == null
                        ? 'Select date'
                        : DateFormat('EEE, MMM dd, yyyy').format(_selectedDate!),
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDate == null ? Colors.grey : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // GUESTS
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adults',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCounter(_adults, (v) => setState(() => _adults = v)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Children',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCounter(_children, (v) => setState(() => _children = v)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // CHECK BUTTON
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _checking ? null : _checkAvailability,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _checking
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Check Availability'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounter(int value, Function(int) onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            color: Colors.blue,
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TIME SLOTS
  // ---------------------------------------------------------------------------

  Widget _buildTimeSlots() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Time Slots',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _availableSlots.map((slot) {
              final isSelected = _selectedSlot?['id'] == slot['id'];
              final isAvailable = slot['is_available'] == true ||
                  slot['is_available'] == 1;

              return InkWell(
                onTap: isAvailable
                    ? () => setState(() => _selectedSlot = slot)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue
                        : isAvailable
                            ? Colors.white
                            : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.blue
                          : isAvailable
                              ? Colors.grey[300]!
                              : Colors.grey[400]!,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        slot['name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? Colors.black87
                                  : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${slot['price']}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : isAvailable
                                  ? Colors.blue
                                  : Colors.grey,
                        ),
                      ),
                      if (!isAvailable)
                        Text(
                          'Full',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------------------------

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    final features = _data!['features'];
    if (features is! List || features.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      'Features',
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: features.map<Widget>((f) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  f['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIncluded() {
    final included = _data!['include'];
    if (included is! List || included.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      'What\'s Included',
      Column(
        children: included.map<Widget>((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item['title'] ?? '',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviews() {
    final reviews = _data!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      'Reviews',
      SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: reviews.length,
          itemBuilder: (_, i) {
            final r = reviews[i];
            final rating = int.tryParse(r['rate_number'].toString()) ?? 0;

            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 14),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: r['author']?['avatar'] != null
                                ? NetworkImage(r['author']['avatar'])
                                : null,
                            child: r['author']?['avatar'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['author']?['name'] ?? 'Guest',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating ? Icons.star : Icons.star_border,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (r['title'] != null)
                        Text(
                          r['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            r['content'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FLOATING BOOK BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildFloatingBookButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
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
          child: Row(
            children: [
              if (_selectedSlot != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total Price',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '\$${_calculateTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _bookNow,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Book Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}

// =============================================================================
// BOAT CHECKOUT SCREEN
// =============================================================================

class BoatCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String boatTitle;
  final DateTime date;
  final Map<String, dynamic> timeSlot;
  final int adults;
  final int children;
  final double total;

  const BoatCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.boatTitle,
    required this.date,
    required this.timeSlot,
    required this.adults,
    required this.children,
    required this.total,
  }) : super(key: key);

  @override
  State<BoatCheckoutScreen> createState() => _BoatCheckoutScreenState();
}

class _BoatCheckoutScreenState extends State<BoatCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();

  bool _isSubmitting = false;

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

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        throw Exception('Authentication required');
      }

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      // STEP 1: CHECKOUT PREVIEW (REQUIRED)
      print('📤 Loading Checkout Preview...');

      final previewRes = await http.get(
        Uri.parse(
          'https://megatour.vn/api/booking/${widget.bookingCode}/checkout',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      print('📥 Preview Response: ${previewRes.statusCode}');

      if (previewRes.statusCode != 200) {
        throw Exception('Checkout preview failed');
      }

      print('✅ Preview Loaded');

      // STEP 2: DO CHECKOUT
      print('📤 Processing Checkout...');

      final checkoutBody = {
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address_line_1': _address.text.trim(),
        'customer_notes': _notes.text.trim(),
        'payment_gateway': 'offline_payment',
        'term_conditions': 'on',
      };

      final checkoutEncoded = checkoutBody.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final checkoutRes = await http.post(
        Uri.parse('https://megatour.vn/api/booking/doCheckout'),
        headers: headers,
        body: checkoutEncoded,
      );

      print('📥 Checkout Response: ${checkoutRes.statusCode}');
      print('Body: ${checkoutRes.body}');

      final checkoutData = jsonDecode(checkoutRes.body);

      if (checkoutRes.statusCode != 200) {
        throw Exception(checkoutData['message'] ?? 'Checkout failed');
      }

      final isSuccess = checkoutData['status'] == 1 ||
          checkoutData['status'] == true ||
          checkoutData['booking_code'] != null;

      if (!isSuccess) {
        throw Exception(checkoutData['message'] ?? 'Checkout failed');
      }

      final finalCode = checkoutData['booking_code'] ?? widget.bookingCode;

      print('✅ Checkout Complete: $finalCode');

      if (mounted) {
        _showSuccessDialog(finalCode);
      }
    } catch (e) {
      print('❌ Checkout error: $e');

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
              'Your boat booking has been successfully created.',
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
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boat Checkout'),
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
                widget.boatTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEE, MMM dd, yyyy').format(widget.date),
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                widget.timeSlot['name'] ?? '',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.adults} Adults, ${widget.children} Children',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 32),

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${widget.timeSlot['name']}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "\$${widget.timeSlot['price']} × ${widget.adults}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(
              "\$${widget.total.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ],
    ),
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
                    "Confirm Booking - \$${widget.total.toStringAsFixed(2)}",
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
}