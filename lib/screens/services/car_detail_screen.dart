import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

// =============================================================================
// 1. THEME CONSTANTS (Automotive Blue Theme)
// =============================================================================
Color kCarDark = Color(0xFF0F172A);
Color kCarBlue = Color(0xFF3B82F6);
Color kCarIndigo = Color(0xFF6366F1);
Color kCarSurface = Color(0xFFF1F5F9);

// =============================================================================
// 2. CAR DETAIL SCREEN
// =============================================================================
class CarDetailScreen extends StatefulWidget {
  final int carId;
  CarDetailScreen({Key? key, required this.carId}) : super(key: key);

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Map<String, dynamic>? _carData;
  bool _loading = true;
  bool _submitting = false;
  
  DateTime? _pickupDate;
  DateTime? _returnDate;
  
  final PageController _galleryController = PageController();
  Timer? _galleryTimer;
  int _currentGalleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCar();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _galleryController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadCar() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}car/detail/${widget.carId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _carData = json['data'];
            _loading = false;
          });
          _startAutoSlide();
        }
      } else {
        throw Exception('Failed to load car details');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Error loading car: $e");
    }
  }

  void _startAutoSlide() {
    final gallery = _carData?['gallery'];
    if (gallery is! List || gallery.length < 2) return;
    
    _galleryTimer = Timer.periodic(Duration(seconds: 5), (_) {
      if (!mounted) return;
      _currentGalleryIndex = (_currentGalleryIndex + 1) % gallery.length;
      if (_galleryController.hasClients) {
        _galleryController.animateToPage(
          _currentGalleryIndex,
          duration: Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // CALCULATIONS
  // ---------------------------------------------------------------------------
  int get _days {
    if (_pickupDate == null || _returnDate == null) return 0;
    final days = _returnDate!.difference(_pickupDate!).inDays;
    return days > 0 ? days : 0; // Ensure at least 0
  }

  double _calculateTotal() {
    if (_carData == null || _days == 0) return 0.0;
    
    // Price Logic (Sale price takes priority)
    double price = double.tryParse('${_carData!['sale_price']}') ?? 0;
    if (price == 0) {
      price = double.tryParse('${_carData!['price']}') ?? 0;
    }

    // Add extra fees (100 + 200 as per your logic)
    // Ideally, parse 'booking_fee' from API, but sticking to your rule:
    return (price * _days) + 100 + 200;
  }

  // ---------------------------------------------------------------------------
  // BOOKING LOGIC (Add to Cart -> Navigate to Checkout)
  // ---------------------------------------------------------------------------
  Future<void> _bookNow() async {
    if (_pickupDate == null || _returnDate == null) return _snack('Select pickup and return dates', Colors.orange);
    if (_days < 1) return _snack('Invalid date range', Colors.orange);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return _snack('Please login to continue', Colors.red);

    setState(() => _submitting = true);

    try {
      final body = {
        'service_id': widget.carId.toString(),
        'service_type': 'car',
        'start_date': DateFormat('yyyy-MM-dd').format(_pickupDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
        'number': '1',
      };

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/addToCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json', // Car API often prefers JSON
        },
        body: jsonEncode(body),
      );

      final json = jsonDecode(res.body);

      if (res.statusCode == 200 && (json['status'] == 1 || json['status'] == true)) {
        String? code = json['booking_code'] ?? json['data']?['code'] ?? json['code'];
        
        if (code != null) {
           if (mounted) {
             Navigator.push(
               context, 
               MaterialPageRoute(
                 builder: (_) => CarCheckoutScreen(
                   bookingCode: code!,
                   carTitle: _carData?['title'] ?? 'Car Rental',
                   pickupDate: _pickupDate!,
                   returnDate: _returnDate!,
                   total: _calculateTotal(),
                 ),
               ),
             );
           }
        } else {
           throw Exception('No booking code found');
        }
      } else {
        throw Exception(json['message'] ?? 'Failed to add to cart');
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_carData == null) return Scaffold(body: Center(child: Text(context.l10n.carNotFound)));

    return Scaffold(
      backgroundColor: kCarSurface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeaderInfo(),
                    _buildBookingCard(),
                    _buildSpecsGrid(),
                    _buildFeatures(),
                    _buildDescription(),
                    _buildFAQs(),
                    _buildReviews(),
                    _buildRelatedCars(),
                    SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  SliverAppBar _buildAppBar() {
    final gallery = _carData!['gallery'] as List? ?? [];
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: kCarDark,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
        child: IconButton(icon: Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            icon: Icon(_carData!['is_wishlist'] == 1 ? Icons.favorite : Icons.favorite_border, color: kCarBlue),
            onPressed: () {}, 
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            gallery.isNotEmpty 
              ? PageView.builder(
                  controller: _galleryController,
                  itemCount: gallery.length,
                  itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
                )
              : Image.network(_carData!['image'] ?? '', fit: BoxFit.cover),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.transparent, kCarDark.withOpacity(0.9)],
                ),
              ),
            ),
            
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_carData!['location'] != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, color: kCarBlue, size: 16),
                        SizedBox(width: 4),
                        Text(
                          _carData!['location']['name'],
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  SizedBox(height: 8),
                  Text(
                    _carData!['title'] ?? '',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final review = _carData!['review_score'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(color: kCarBlue.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.directions_car, color: kCarBlue),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.pricePerDay, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(
                    "\$${_carData!['sale_price'] ?? _carData!['price'] ?? 0}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kCarDark),
                  ),
                ],
              ),
            ],
          ),
          if (review != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    SizedBox(width: 4),
                    Text(review['score_total'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text('${review['total_review']} reviews', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }

  // --- BOOKING CARD (Rental Style) ---
  Widget _buildBookingCard() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [kCarDark, kCarIndigo]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: kCarIndigo.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8))],
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(child: _dateButton("PICKUP", _pickupDate, true)),
                  Container(
                    height: 40, width: 1, color: Colors.white24,
                    margin: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Expanded(child: _dateButton("RETURN", _returnDate, false)),
                ],
              ),
            ),
            
            if (_days > 0)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$_days Days Rental", style: TextStyle(color: Colors.white70)),
                    Text("Total: \$${_calculateTotal().toStringAsFixed(0)}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(String label, DateTime? date, bool isPickup) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context, 
          firstDate: now, 
          lastDate: now.add(Duration(days: 365)),
          initialDate: date ?? now,
        );
        if (d != null) {
          setState(() {
            if (isPickup) {
              _pickupDate = d;
              if (_returnDate != null && _returnDate!.isBefore(d)) _returnDate = d.add(Duration(days: 1));
            } else {
              _returnDate = d;
            }
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
          SizedBox(height: 4),
          Row(
            children: [
              Text(
                date == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(date),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsGrid() {
    final passenger = _carData!['passenger'] ?? 0;
    final gear = _carData!['gear'] ?? 'N/A';
    final baggage = _carData!['baggage'] ?? 0;
    final door = _carData!['door'] ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _specItem(Icons.person, '$passenger', 'Seats'),
          _specItem(Icons.settings, '$gear', 'Gear'),
          _specItem(Icons.luggage, '$baggage', 'Bags'),
          _specItem(Icons.door_front_door, '$door', 'Doors'),
        ],
      ),
    );
  }

  Widget _specItem(IconData icon, String val, String label) {
    return Container(
      width: 75,
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: kCarBlue, size: 22),
          SizedBox(height: 6),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: kCarDark)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    // Parsing 'terms' -> '10' -> 'child' for features
    final terms = _carData!['terms'];
    List<dynamic> features = [];
    if (terms != null && terms is Map) {
      if (terms['10'] != null && terms['10']['child'] != null) {
        features = terms['10']['child'];
      }
    }
    
    if (features.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Features"),
          SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: features.map((f) => Chip(
              label: Text(f['title'] ?? ''),
              backgroundColor: Colors.white,
              avatar: Icon(Icons.check_circle, size: 16, color: kCarBlue),
              side: BorderSide(color: Colors.grey.shade300),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Description"),
          SizedBox(height: 8),
          HtmlWidget(
            _carData!['content'] ?? '',
            textStyle: TextStyle(color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQs() {
    final faqs = _carData!['faqs'];
    if (faqs is! List || faqs.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          _buildSectionTitle("FAQs"),
          SizedBox(height: 10),
          ...faqs.map((f) => Container(
            margin: EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: Text(f['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              childrenPadding: EdgeInsets.all(16),
              children: [HtmlWidget(f['content'] ?? '')],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    final reviews = _carData!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: _buildSectionTitle("Reviews (${reviews.length})"),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (_, i) {
              final r = reviews[i];
              return Container(
                width: 280,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kCarBlue.withOpacity(0.1),
                          child: Icon(Icons.person, size: 18, color: kCarBlue),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(r['author']?['name'] ?? 'User', style: TextStyle(fontWeight: FontWeight.bold))),
                        Row(children: [Icon(Icons.star, size: 14, color: Colors.amber), Text('${r['rate_number']}', style: TextStyle(fontWeight: FontWeight.bold))]),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Expanded(child: Text(r['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedCars() {
    final related = _carData!['related'];
    if (related is! List || related.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: _buildSectionTitle("Related Cars"),
        ),
        SizedBox(
          height: 240,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = related[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(carId: item['id']))),
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(item['image'] ?? '', width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("\$${item['price']}", style: TextStyle(color: kCarBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, -5))],
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.totalEstimate, style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("\$${_calculateTotal().toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kCarDark)),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCarBlue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              child: _submitting
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(context.l10n.bookNow1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kCarDark));
}

// =============================================================================
// 3. CAR CHECKOUT SCREEN
// =============================================================================
class CarCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String carTitle;
  final DateTime pickupDate;
  final DateTime returnDate;
  final double total;

  CarCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.carTitle,
    required this.pickupDate,
    required this.returnDate,
    required this.total,
  }) : super(key: key);

  @override
  State<CarCheckoutScreen> createState() => _CarCheckoutScreenState();
}

class _CarCheckoutScreenState extends State<CarCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _country = TextEditingController(text: 'VN');
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose();
    _phone.dispose(); _address.dispose(); _notes.dispose(); _country.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      // 1. Checkout Preview
      try {
        await http.get(Uri.parse('${ApiConfig.baseUrl}booking/${widget.bookingCode}/checkout'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      } catch (e) {
        debugPrint('Preview skipped: $e');
      }

      // 2. Do Checkout
      final body = {
        'code': widget.bookingCode,
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'address_line_1': _address.text.trim(),
        'country': _country.text.trim(),
        'customer_notes': _notes.text.trim(),
        'payment_gateway': 'offline',
        'term_conditions': 'on',
      };

      final checkoutRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/doCheckout'),
        headers: headers,
        body: jsonEncode(body),
      );

      // Handle Route Error Bypass
      if (checkoutRes.statusCode == 500 && checkoutRes.body.contains('Route [booking.thankyou] not defined')) {
        if (mounted) _showSuccessDialog(widget.bookingCode);
        return;
      }

      final checkoutData = jsonDecode(checkoutRes.body);

      if (checkoutRes.statusCode != 200) {
        if (checkoutData['errors'] != null) {
           final Map errors = checkoutData['errors'];
           if (errors.isNotEmpty) throw Exception(errors.values.first[0]);
        }
        throw Exception(checkoutData['message'] ?? 'Checkout failed');
      }

      final isSuccess = checkoutData['status'] == 1 || checkoutData['status'] == true || checkoutData['booking_code'] != null;
      if (!isSuccess) throw Exception(checkoutData['message'] ?? 'Checkout failed');

      if (mounted) _showSuccessDialog(checkoutData['booking_code'] ?? widget.bookingCode);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [Icon(Icons.check_circle, color: kCarBlue, size: 64), SizedBox(height: 16), Text(context.l10n.bookingConfirmed1)]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.yourCarRentalIsConfirmed, textAlign: TextAlign.center),
            SizedBox(height: 16),
            SelectableText(code, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kCarBlue)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text(context.l10n.backToHome1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCarSurface,
      appBar: AppBar(title: Text(context.l10n.checkout1, style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(context.l10n.totalAmount, style: TextStyle(color: Colors.grey[600])), Text('\$${widget.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: kCarBlue, fontSize: 18))]),
                    Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${DateFormat('MMM dd').format(widget.pickupDate)} - ${DateFormat('MMM dd').format(widget.returnDate)}"), Text(context.l10n.carRental, style: TextStyle(fontWeight: FontWeight.bold))]),
                  ],
                ),
              ),
              SizedBox(height: 24),
              Text(context.l10n.guestInfo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _input(_firstName, 'First Name', Icons.person),
              _input(_lastName, 'Last Name', Icons.person),
              _input(_email, 'Email', Icons.email, type: TextInputType.emailAddress),
              _input(_phone, 'Phone', Icons.phone, type: TextInputType.phone),
              _input(_address, 'Address', Icons.home),
              _input(_country, 'Country', Icons.flag),
              _input(_notes, 'Notes (Optional)', Icons.note, req: false),
              SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCheckout,
                  style: ElevatedButton.styleFrom(backgroundColor: kCarBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? CircularProgressIndicator(color: Colors.white) : Text(context.l10n.confirmPay, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon, {TextInputType type = TextInputType.text, bool req = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c, keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: Colors.white),
        validator: (v) => req && (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }
}