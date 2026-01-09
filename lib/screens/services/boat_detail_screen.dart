import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

// =============================================================================
// 1. THEME CONSTANTS
// =============================================================================
Color kPrimaryBlue = Color(0xFF0A2342);
Color kAccentTeal = Color(0xFF00A896);
Color kAccentOrange = Color(0xFFFA824C);
Color kLightGreyBg = Color(0xFFF5F7FA);

// =============================================================================
// 2. BOAT DETAIL SCREEN
// =============================================================================
class BoatDetailScreen extends StatefulWidget {
  final int boatId;

  BoatDetailScreen({
    Key? key,
    required this.boatId,
  }) : super(key: key);

  @override
  State<BoatDetailScreen> createState() => _BoatDetailScreenState();
}

class _BoatDetailScreenState extends State<BoatDetailScreen> {
  // Data State
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _checking = false;
  bool _submitting = false;

  // Booking Configuration State
  String _bookingType = 'day'; // 'day' or 'hour'

  // Input State
  DateTime? _startDate;
  DateTime? _endDate; // Daily Rental
  TimeOfDay? _startTime; // Hourly Rental
  int _durationHours = 1; // Hourly Rental
  int _adults = 1;
  int _children = 0;

  // UI State
  final PageController _pageController = PageController();
  Timer? _galleryTimer;
  int _currentPage = 0;

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
  // DATA LOADING & HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _loadBoat() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}boat/detail/${widget.boatId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _data = json['data'];
            _loading = false;
            // Auto-detect default booking type
            if (_hasDaily() && !_hasHourly()) {
              _bookingType = 'day';
            } else if (!_hasDaily() && _hasHourly()) {
              _bookingType = 'hour';
            } else {
              _bookingType = 'day';
            }
          });
          _startAutoSlide();
        }
      } else {
        throw Exception('Failed to load boat details');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Load error: $e');
    }
  }

  void _startAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length < 2) return;
    _galleryTimer = Timer.periodic(Duration(seconds: 4), (_) {
      if (!mounted) return;
      _currentPage = (_currentPage + 1) % gallery.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  bool _hasHourly() => _data?['price_per_hour'] != null;
  bool _hasDaily() => _data?['price_per_day'] != null;

  double _getPricePerHour() => double.tryParse('${_data?['price_per_hour']}') ?? 0.0;
  double _getPricePerDay() => double.tryParse('${_data?['price_per_day']}') ?? 0.0;
  double _getDefaultPrice() => double.tryParse('${_data?['price']}') ?? 0.0;

  double _calculateTotal() {
    if (_data == null) return 0.0;
    if (_bookingType == 'hour') {
      if (_startDate == null || _startTime == null) return 0.0;
      double price = _getPricePerHour();
      if (price == 0) price = _getDefaultPrice();
      return price * _durationHours;
    } else {
      if (_startDate == null || _endDate == null) return 0.0;
      int days = _endDate!.difference(_startDate!).inDays;
      if (days < 1) days = 1;
      double price = _getPricePerDay();
      if (price == 0) price = _getDefaultPrice();
      return price * days;
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIC: CHECK AVAILABILITY
  // ---------------------------------------------------------------------------

  Future<void> _checkAvailability() async {
    if (_startDate == null) return _snack('Select start date', kAccentOrange);
    if (_bookingType == 'day' && _endDate == null) return _snack('Select end date', kAccentOrange);
    if (_bookingType == 'hour' && _startTime == null) return _snack('Select start time', kAccentOrange);

    setState(() => _checking = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);

      final Map<String, String> queryParams = {
        'start_date': startStr,
        'adults': _adults.toString(),
        'children': _children.toString(),
      };

      if (_bookingType == 'hour') {
        final h = _startTime!.hour.toString().padLeft(2, '0');
        final m = _startTime!.minute.toString().padLeft(2, '0');
        queryParams['start_time'] = '$h:$m';
        queryParams['duration'] = _durationHours.toString();
        queryParams['type'] = 'hour';
      } else {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
        queryParams['start_time'] = '00:00';
        queryParams['type'] = 'day';
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}boat/availability-booking/${widget.boatId}')
    .replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 1 || json['status'] == true) {
          _snack('Available! You can proceed to book.', Colors.green);
        } else {
          String msg = json['message']?.toString() ?? 'Not available';
          if (json['message'] is Map && (json['message'] as Map).isNotEmpty) {
            msg = json['message'].values.first[0];
          }
          _snack(msg, Colors.redAccent);
        }
      } else {
        _snack('Server Error: ${res.statusCode}', Colors.red);
      }
    } catch (e) {
      _snack('Connection error', Colors.red);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIC: BOOK NOW
  // ---------------------------------------------------------------------------

  Future<void> _bookNow() async {
    if (_calculateTotal() <= 0) return _snack('Complete your selection', kAccentOrange);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return _snack('Please login to continue', Colors.red);

    setState(() => _submitting = true);

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final totalGuests = _adults + _children;

      final Map<String, String> body = {
        'service_id': widget.boatId.toString(),
        'service_type': 'boat',
        'start_date': startStr,
        'adults': _adults.toString(),
        'children': _children.toString(),
        'guests': totalGuests.toString(), // SUMMED GUESTS
      };

      if (_bookingType == 'day') {
        // DAILY LOGIC
        int days = _endDate!.difference(_startDate!).inDays;
        if (days < 1) days = 1;
        body['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
        body['start_time'] = '00:00';
        body['day'] = days.toString();
        body['type_date'] = 'per_day';
      } else {
        // HOURLY LOGIC
        body['end_date'] = startStr;
        final h = _startTime!.hour.toString().padLeft(2, '0');
        final m = _startTime!.minute.toString().padLeft(2, '0');
        body['start_time'] = '$h:$m';
        body['hour'] = _durationHours.toString();
        body['type_date'] = 'per_hour';
      }

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/addToCart'),
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
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => BoatCheckoutScreen(
                bookingCode: code!,
                boatTitle: _data?['title'] ?? 'Boat Rental',
                date: _startDate!,
                bookingDesc: _bookingType == 'day'
                    ? 'Daily Rental'
                    : 'Hourly Rental ($_durationHours hours)',
                adults: _adults,
                children: _children,
                total: _calculateTotal(),
              ),
            ));
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
    if (_data == null) return Scaffold(body: Center(child: Text(context.l10n.boatNotFound)));

    return Scaffold(
      backgroundColor: kLightGreyBg,
      body: Stack(
        children: [
          // 1. Ambient Background
          Container(
            height: 450,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryBlue.withOpacity(0.12), kLightGreyBg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. Scrollable Content
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      SizedBox(height: 24),
                      _buildSpecsGrid(),
                      SizedBox(height: 24),
                      _buildSmartBookingCard(),
                      SizedBox(height: 24),
                      _buildSectionTitle("Description"),
                      SizedBox(height: 8),
                      HtmlWidget(
                        _data!['content'] ?? '',
                        textStyle: TextStyle(color: Colors.grey[800], height: 1.6),
                      ),
                      SizedBox(height: 24),
                      _buildAmenities(),
                      SizedBox(height: 24),
                      _buildFAQs(),
                      SizedBox(height: 24),
                      _buildReviews(),
                      SizedBox(height: 24),
                      _buildRelatedBoats(),
                      SizedBox(height: 120), // Padding for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Bottom Action Bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------------------

  SliverAppBar _buildSliverAppBar() {
    final gallery = _data!['gallery'] as List? ?? [];
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: kPrimaryBlue,
      leading: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: kPrimaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(
              _data!['is_wishlist'] == 1 ? Icons.favorite : Icons.favorite_border,
              color: kAccentOrange,
            ),
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
                : Container(color: Colors.grey[300]),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black26, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final location = _data!['location']?['name'] ?? _data!['address'] ?? 'Unknown Location';
    final review = _data!['review_score'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _data!['title'] ?? 'Boat Name',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: kPrimaryBlue, height: 1.1),
              ),
            ),
            if (review != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kAccentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.star, color: kAccentOrange, size: 16),
                    SizedBox(width: 4),
                    Text(review['score_total'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: kAccentOrange)),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(child: Text(location, style: TextStyle(color: Colors.grey, fontSize: 15))),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            if (_hasDaily()) _priceBadge("Daily", "\$${_getPricePerDay()}", kAccentOrange),
            if (_hasDaily() && _hasHourly()) SizedBox(width: 12),
            if (_hasHourly()) _priceBadge("Hourly", "\$${_getPricePerHour()}", kAccentTeal),
          ],
        )
      ],
    );
  }

  Widget _buildSpecsGrid() {
    final maxGuest = _data!['max_guest'] ?? 0;
    final cabin = _data!['cabin'] ?? 0;
    final speed = _data!['speed'] ?? 'N/A';
    final length = _data!['length'] ?? 'N/A';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _specItem(Icons.group, '$maxGuest', 'Guests'),
        _specItem(Icons.bed, '$cabin', 'Cabins'),
        _specItem(Icons.speed, '$speed', 'Speed'),
        _specItem(Icons.straighten, '$length', 'Length'),
      ],
    );
  }

  Widget _specItem(IconData icon, String val, String label) {
    return Container(
      width: 80,
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: kPrimaryBlue.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: kAccentTeal, size: 24),
          SizedBox(height: 8),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSmartBookingCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasHourly() && _hasDaily())
            Container(
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: _typeButton('By Day', 'day')),
                  Expanded(child: _typeButton('By Hour', 'hour')),
                ],
              ),
            ),

          if (_bookingType == 'day') ...[
            _datePickerField("Start Date", _startDate, (d) => setState(() => _startDate = d)),
            SizedBox(height: 12),
            _datePickerField("End Date", _endDate, (d) => setState(() => _endDate = d)),
          ] else ...[
            _datePickerField("Date", _startDate, (d) => setState(() => _startDate = d)),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _timePickerField()),
                SizedBox(width: 12),
                Expanded(child: _durationDropdown()),
              ],
            )
          ],

          Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.guests1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  _circleBtn(Icons.remove, () => setState(() => _adults = _adults > 1 ? _adults - 1 : 1)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("$_adults", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  _circleBtn(Icons.add, () => setState(() => _adults++)),
                ],
              )
            ],
          ),

          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _checking ? null : _checkAvailability,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: kPrimaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _checking
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.l10n.checkAvailability1, style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAmenities() {
    final terms = _data!['terms'];
    List<dynamic> amenities = [];
    if (terms is Map) {
      terms.forEach((k, v) {
        if (v['child'] is List) amenities.addAll(v['child']);
      });
    }
    if (amenities.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Amenities"),
        SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: amenities.map((a) => Chip(
            label: Text(a['title'] ?? ''),
            backgroundColor: Colors.white,
            avatar: Icon(Icons.check_circle, size: 16, color: kAccentTeal),
            side: BorderSide(color: Colors.grey.shade200),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildFAQs() {
    final faqs = _data!['faqs'];
    if (faqs is! List || faqs.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("FAQs"),
        SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            final faq = faqs[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: ExpansionTile(
                title: Text(faq['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  HtmlWidget(faq['content'] ?? '', textStyle: TextStyle(color: Colors.grey[700], height: 1.4)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviews() {
    final reviews = _data!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Reviews (${reviews.length})"),
            Text(context.l10n.seeAll1, style: TextStyle(color: kAccentTeal, fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
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
                          backgroundColor: Colors.grey[200],
                          radius: 16,
                          child: Icon(Icons.person, color: Colors.grey, size: 18),
                        ),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['author']?['name'] ?? 'Guest', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(r['created_at'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(r['created_at'])) : '', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          ],
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: kAccentOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.star, size: 12, color: kAccentOrange),
                              SizedBox(width: 4),
                              Text('${r['rate_number']}', style: TextStyle(fontWeight: FontWeight.bold, color: kAccentOrange, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Expanded(
                      child: Text(r['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedBoats() {
    final related = _data!['related'];
    if (related is! List || related.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("You Might Also Like"),
        SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => SizedBox(width: 16),
            itemBuilder: (_, i) {
              final boat = related[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoatDetailScreen(boatId: boat['id']))),
                child: Container(
                  width: 220,
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
                          child: Image.network(
                            boat['image'] ?? '',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
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
                              Text(boat['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Expanded(child: Text(boat['location']?['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey, fontSize: 12))),
                                ],
                              ),
                              Text("\$${boat['price']}", style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue, fontSize: 16)),
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
        padding: EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0,-5))],
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.totalEstimate, style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("\$${_calculateTotal().toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kPrimaryBlue)),
              ],
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentOrange,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: _submitting
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(context.l10n.bookNow1, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // --- UI Helpers ---
  Widget _buildSectionTitle(String title) => Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryBlue));

  Widget _typeButton(String label, String value) {
    bool selected = _bookingType == value;
    return GestureDetector(
      onTap: () => setState(() => _bookingType = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: selected ? kPrimaryBlue : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  Widget _datePickerField(String label, DateTime? val, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(Duration(days: 90)), initialDate: val ?? DateTime.now());
        if (d != null) onPick(d);
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(val == null ? label : DateFormat('EEE, dd MMM').format(val), style: TextStyle(color: val == null ? Colors.grey : kPrimaryBlue, fontWeight: FontWeight.bold)),
          Icon(Icons.calendar_today, size: 18, color: kAccentTeal),
        ]),
      ),
    );
  }

  Widget _timePickerField() {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: 8, minute: 0));
        if (t != null) setState(() => _startTime = t);
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_startTime == null ? "Time" : _startTime!.format(context), style: TextStyle(color: _startTime == null ? Colors.grey : kPrimaryBlue, fontWeight: FontWeight.bold)),
          Icon(Icons.access_time, size: 18, color: kAccentTeal),
        ]),
      ),
    );
  }

  Widget _durationDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _durationHours, isExpanded: true,
          items: List.generate(8, (i) => i + 1).map((h) => DropdownMenuItem(value: h, child: Text("$h Hour${h>1?'s':''}", style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryBlue)))).toList(),
          onChanged: (v) => setState(() => _durationHours = v!),
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!)),
        child: Icon(icon, size: 18, color: kPrimaryBlue),
      ),
    );
  }

  Widget _priceBadge(String label, String price, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          Text(price, style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// =============================================================================
// 3. BOAT CHECKOUT SCREEN (FIXED & INTEGRATED)
// =============================================================================

class BoatCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String boatTitle;
  final DateTime date;
  final String bookingDesc;
  final int adults;
  final int children;
  final double total;

  BoatCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.boatTitle,
    required this.date,
    required this.bookingDesc,
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
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      // 1. Checkout Preview (Ignore 500s)
      try {
        await http.get(Uri.parse('${ApiConfig.baseUrl}booking/${widget.bookingCode}/checkout'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      } catch (e) {
        debugPrint('Preview skipped: $e');
      }

      // 2. Do Checkout
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

      final checkoutRes = await http.post(
        Uri.parse('${ApiConfig.baseUrl}booking/doCheckout'),
        headers: headers,
        body: checkoutBody,
      );

      // FIX: Handle "Route not defined" error as success
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
        title: Column(children: [Icon(Icons.check_circle, color: kAccentTeal, size: 64), SizedBox(height: 16), Text(context.l10n.bookingConfirmed1)]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.yourBookingWasSuccessful),
            SizedBox(height: 16),
            SelectableText(code, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryBlue)),
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
      backgroundColor: kLightGreyBg,
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
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(context.l10n.totalAmount, style: TextStyle(color: Colors.grey[600])), Text('\$${widget.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: kAccentOrange, fontSize: 18))]),
                    Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MMM dd').format(widget.date)), Text(widget.bookingDesc, style: TextStyle(fontWeight: FontWeight.bold))]),
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
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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