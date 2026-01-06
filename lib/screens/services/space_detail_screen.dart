import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// 1. THEME CONSTANTS (Vibrant Airbnb Ambient)
// =============================================================================
const Color kSpacePrimary = Color(0xFFFF385C);
const Color kSpaceGradient1 = Color(0xFFE61E4D);
const Color kSpaceGradient2 = Color(0xFFD80566);
const Color kSpaceSurface = Color(0xFFFFF0F5); // Light Pinkish Surface
const Color kSpaceText = Color(0xFF222222);

// =============================================================================
// 2. SPACE DETAIL SCREEN
// =============================================================================
class SpaceDetailScreen extends StatefulWidget {
  final int spaceId;

  const SpaceDetailScreen({
    Key? key,
    required this.spaceId,
  }) : super(key: key);

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  // Booking State
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 1;

  // UI State
  final PageController _pageController = PageController();
  Timer? _galleryTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSpace();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadSpace() async {
    try {
      final res = await http.get(
        Uri.parse('https://megatour.vn/api/space/detail/${widget.spaceId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _data = json['data'];
            _loading = false;
          });
          _startAutoSlide();
        }
      } else {
        throw Exception('Failed to load space');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading space: $e');
    }
  }

  void _startAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length < 2) return;

    _galleryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _currentPage = (_currentPage + 1) % gallery.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // CALCULATIONS
  // ---------------------------------------------------------------------------
  int _calculateNights() {
    if (_checkIn == null || _checkOut == null) return 0;
    final nights = _checkOut!.difference(_checkIn!).inDays;
    return nights > 0 ? nights : 0;
  }

  double _calculateTotal() {
    if (_data == null) return 0.0;
    final nights = _calculateNights();
    if (nights == 0) return 0.0;

    double price = double.tryParse('${_data!['sale_price']}') ?? 0.0;
    if (price == 0) price = double.tryParse('${_data!['price']}') ?? 0.0;

    return price * nights;
  }

  // ---------------------------------------------------------------------------
  // BOOKING LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _bookNow() async {
    if (_checkIn == null || _checkOut == null) return _snack('Select dates', Colors.orange);
    if (_calculateNights() < 1) return _snack('Invalid dates', Colors.orange);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return _snack('Please login to reserve', Colors.red);

    setState(() => _submitting = true);

    try {
      final body = {
        'service_id': widget.spaceId.toString(),
        'service_type': 'space',
        'start_date': DateFormat('yyyy-MM-dd').format(_checkIn!),
        'end_date': DateFormat('yyyy-MM-dd').format(_checkOut!),
        'adults': _guests.toString(),
        'children': '0',
      };

      final res = await http.post(
        Uri.parse('https://megatour.vn/api/booking/addToCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      final json = jsonDecode(res.body);

      if (res.statusCode == 200 && (json['status'] == 1 || json['status'] == true)) {
        String? code = json['booking_code'] ?? json['data']?['code'] ?? json['code'];
        
        if (code != null) {
           if (mounted) {
             Navigator.push(
               context, 
               MaterialPageRoute(
                 builder: (_) => SpaceCheckoutScreen(
                   bookingCode: code!,
                   spaceTitle: _data?['title'] ?? 'Space Rental',
                   checkIn: _checkIn!,
                   checkOut: _checkOut!,
                   guests: _guests,
                   total: _calculateTotal(),
                 ),
               ),
             );
           }
        } else {
           throw Exception('No booking code returned');
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return const Scaffold(body: Center(child: Text('Space not found')));

    return Scaffold(
      backgroundColor: kSpaceSurface,
      body: Stack(
        children: [
          // Ambient Background
          Container(
            height: 450,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kSpaceGradient1.withOpacity(0.15), kSpaceSurface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildBookingCard(),
                      const SizedBox(height: 32),
                      _buildAmenities(),
                      const SizedBox(height: 24),
                      _buildDescription(),
                      const SizedBox(height: 24),
                      _buildFAQs(),
                      const SizedBox(height: 24),
                      _buildReviews(),
                      const SizedBox(height: 24),
                      _buildRelatedSpaces(),
                      const SizedBox(height: 120),
                    ],
                  ),
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

  SliverAppBar _buildSliverAppBar() {
    final gallery = _data!['gallery'] as List? ?? [];
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: IconButton(icon: const Icon(Icons.arrow_back, color: kSpacePrimary), onPressed: () => Navigator.pop(context)),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: IconButton(
            icon: Icon(_data!['is_wishlist'] == 1 ? Icons.favorite : Icons.favorite_border, color: kSpacePrimary),
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
                  controller: _pageController,
                  itemCount: gallery.length,
                  itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
                )
              : Image.network(_data!['image'] ?? '', fit: BoxFit.cover),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.2), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final review = _data!['review_score'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _data!['title'] ?? '',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kSpaceText, height: 1.1),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (review != null) ...[
              const Icon(Icons.star, color: kSpacePrimary, size: 18),
              const SizedBox(width: 4),
              Text('${review['score_total']} (${review['total_review']})', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Text("·", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _data!['location']?['name'] ?? '',
                style: const TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- GLASSMORPHISM BOOKING CARD ---
  Widget _buildBookingCard() {
    final price = _data!['sale_price'] ?? _data!['price'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kSpaceGradient1, kSpaceGradient2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kSpaceGradient1.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('\$$price', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const Text(' / night', style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Date Selector
          Row(
            children: [
              Expanded(child: _dateBox("CHECK-IN", _checkIn, true)),
              const SizedBox(width: 12),
              Expanded(child: _dateBox("CHECKOUT", _checkOut, false)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Guests
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("GUESTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                Row(
                  children: [
                    _qtyBtn(Icons.remove, _guests > 1 ? () => setState(() => _guests--) : null),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_guests', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
                    _qtyBtn(Icons.add, () => setState(() => _guests++)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime? date, bool isCheckIn) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context, 
          firstDate: now, 
          lastDate: now.add(const Duration(days: 365)),
          initialDate: date ?? now,
        );
        if (d != null) {
          setState(() {
            if (isCheckIn) {
              _checkIn = d;
              if (_checkOut != null && _checkOut!.isBefore(d)) _checkOut = d.add(const Duration(days: 1));
            } else {
              _checkOut = d;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(date != null ? DateFormat('MMM dd').format(date) : 'Add date', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, color: onTap != null ? Colors.white : Colors.white38, size: 20),
      ),
    );
  }

  Widget _buildAmenities() {
    final terms = _data!['terms'];
    List<dynamic> amenities = [];
    if (terms is Map && terms['4'] != null && terms['4']['child'] is List) {
      amenities = terms['4']['child'];
    }

    if (amenities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("What this place offers"),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: amenities.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 18, color: kSpacePrimary),
                  const SizedBox(width: 8),
                  Text(item['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("About this space"),
        const SizedBox(height: 12),
        HtmlWidget(
          _data!['content'] ?? '',
          textStyle: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800]),
        ),
      ],
    );
  }

  Widget _buildFAQs() {
    final faqs = _data!['faqs'];
    if (faqs is! List || faqs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("FAQs"),
        const SizedBox(height: 12),
        ...faqs.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
          child: ExpansionTile(
            title: Text(f['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            childrenPadding: const EdgeInsets.all(16),
            children: [HtmlWidget(f['content'] ?? '', textStyle: const TextStyle(color: Colors.grey))],
          ),
        )),
      ],
    );
  }

  Widget _buildReviews() {
    final reviews = _data!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Reviews (${reviews.length})"),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final r = reviews[i];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: kSpacePrimary.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: kSpacePrimary.withOpacity(0.1), child: const Icon(Icons.person, color: kSpacePrimary)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['author']?['name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(r['created_at'] != null ? DateFormat('MMM yyyy').format(DateTime.parse(r['created_at'])) : '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Expanded(child: Text(r['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], height: 1.4))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedSpaces() {
    final related = _data!['related'];
    if (related is! List || related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Similar Spaces"),
        const SizedBox(height: 16),
        SizedBox(
          height: 280, // Prevent overflow
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = related[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceDetailScreen(spaceId: item['id']))),
                child: Container(
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(item['image'] ?? '', width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[200])),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text("\$${item['price']}", style: const TextStyle(fontWeight: FontWeight.bold, color: kSpacePrimary, fontSize: 16)),
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
    final canBook = _checkIn != null && _checkOut != null && _calculateNights() > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("\$${_calculateTotal().toStringAsFixed(0)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kSpaceText)),
                if (canBook) Text("for ${_calculateNights()} nights", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : (canBook ? _bookNow : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: kSpacePrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Reserve", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kSpaceText));
}

// =============================================================================
// 3. SPACE CHECKOUT SCREEN
// =============================================================================

class SpaceCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String spaceTitle;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final double total;

  const SpaceCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.spaceTitle,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.total,
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

      final headers = {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/x-www-form-urlencoded'};

      try {
        await http.get(Uri.parse('https://megatour.vn/api/booking/${widget.bookingCode}/checkout'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      } catch (e) {
        debugPrint('Preview skipped: $e');
      }

      final checkoutBody = {
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

      final checkoutRes = await http.post(Uri.parse('https://megatour.vn/api/booking/doCheckout'), headers: headers, body: checkoutBody);

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
        title: const Column(children: [Icon(Icons.check_circle, color: kSpacePrimary, size: 64), SizedBox(height: 16), Text('Confirmed!')]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Your space is reserved.'), const SizedBox(height: 16), SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kSpaceText))]),
        actions: [TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Back to Home'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Confirm Booking', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total", style: TextStyle(color: Colors.grey[600])), Text('\$${widget.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: kSpacePrimary, fontSize: 18))]),
                  const Divider(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${DateFormat('MMM dd').format(widget.checkIn)} - ${DateFormat('MMM dd').format(widget.checkOut)}"), Text('${widget.guests} Guests', style: const TextStyle(fontWeight: FontWeight.bold))]),
                ]),
              ),
              const SizedBox(height: 32),
              const Text('Guest Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _input(_firstName, 'First Name', Icons.person_outline),
              _input(_lastName, 'Last Name', Icons.person_outline),
              _input(_email, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
              _input(_phone, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
              _input(_address, 'Address', Icons.home_outlined),
              _input(_country, 'Country', Icons.flag_outlined),
              _input(_notes, 'Message (Optional)', Icons.chat_bubble_outline, req: false),
              const SizedBox(height: 40),
              SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: _isSubmitting ? null : _handleCheckout, style: ElevatedButton.styleFrom(backgroundColor: kSpacePrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon, {TextInputType type = TextInputType.text, bool req = true}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white), validator: (v) => req && (v == null || v.isEmpty) ? 'Required' : null));
  }
}