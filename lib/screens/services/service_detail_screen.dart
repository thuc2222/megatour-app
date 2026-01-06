import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';

import '../../services/service_api.dart';
import '../../services/guest_booking_storage.dart'; // 🟢 Added to save history
import '../booking/checkout_screen.dart';

// =============================================================================
// 1. THEME: Modern Hotel Gradient
// =============================================================================
const Color kHotelPrimary = Color(0xFF6C63FF); 
const Color kHotelSecondary = Color(0xFF2D3436);
const Color kHotelSurface = Colors.white;

const LinearGradient kAmbientGradient = LinearGradient(
  colors: [
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFE3F2FD), // Light Blue
    Color(0xFFFBE9E7), // Light Peach
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;
  final String serviceType;

  const ServiceDetailScreen({
    Key? key,
    required this.serviceId,
    this.serviceType = 'hotel',
  }) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  // 🟢 Logic kept exactly as requested
  final ServiceApi _api = ServiceApi();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _checking = false;
  bool _submitting = false;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));

  int _adults = 2;
  int _children = 0;

  List<dynamic> _rooms = [];
  final Map<int, int> _roomQty = {};

  // 🔹 Gallery
  final PageController _pageController = PageController();
  Timer? _galleryTimer;
  int _currentPage = 0;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadHotel();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOAD (Logic Kept)
  // ---------------------------------------------------------------------------

  Future<void> _loadHotel() async {
    try {
      final res = await _api.getServiceDetailRaw(
        id: widget.serviceId,
        serviceType: 'hotel',
      );

      setState(() {
        _data = res is Map ? res['data'] : null;
        _loading = false;
      });

      _startGalleryAutoSlide();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _startGalleryAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length <= 1) return;

    _galleryTimer?.cancel();
    _galleryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;

      _currentPage = (_currentPage + 1) % gallery.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // AVAILABILITY (Logic Kept)
  // ---------------------------------------------------------------------------

  Future<void> _checkAvailability() async {
    setState(() => _checking = true);

    try {
      final res = await _api.checkAvailability(
        id: widget.serviceId,
        serviceType: 'hotel',
        start: DateFormat('yyyy-MM-dd').format(_startDate),
        end: DateFormat('yyyy-MM-dd').format(_endDate),
        adults: _adults,
        children: _children,
      );

      final data = res is Map<String, dynamic> ? res['data'] : null;

      setState(() {
        _rooms = data is List ? data : [];
        _checking = false;
        
        // Reset qty on new check
        _roomQty.clear();
        for(var r in _rooms) {
           int id = int.tryParse(r['id'].toString()) ?? 0;
           if(id > 0) _roomQty[id] = 0;
        }
      });
    } catch (_) {
      setState(() => _checking = false);
    }
  }

  // Helper to calc total for history
  double _calculateTotal() {
    double total = 0.0;
    int nights = _endDate.difference(_startDate).inDays;
    if (nights < 1) nights = 1;
    for (var r in _rooms) {
      int id = int.tryParse(r['id'].toString()) ?? 0;
      int qty = _roomQty[id] ?? 0;
      if (qty > 0) {
        double price = double.tryParse('${r['price']}'.replaceAll(',', '')) ?? 0.0;
        total += price * qty;
      }
    }
    return total * nights;
  }

  // ---------------------------------------------------------------------------
  // BOOK (Logic Kept + Added History Save)
  // ---------------------------------------------------------------------------

  Future<void> _bookNow() async {
    if (_roomQty.values.every((e) => e == 0)) {
      _snack('Please select at least one room', Colors.orange);
      return;
    }

    setState(() => _submitting = true);

    try {
      final res = await _api.createBooking(
        objectModel: 'hotel',
        objectId: widget.serviceId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        adults: _adults,
        children: _children,
        items: _roomQty,
      );

      setState(() => _submitting = false);

      if (res is Map && res['status'] == 1) {
        // 🟢 SAVE TO HISTORY
        if (res['booking_code'] != null) {
           await GuestBookingStorage.saveBooking(
             bookingCode: res['booking_code'],
             serviceType: 'hotel',
             serviceName: _data?['title'] ?? 'Hotel',
             startDate: DateFormat('yyyy-MM-dd').format(_startDate),
             endDate: DateFormat('yyyy-MM-dd').format(_endDate),
             total: '\$${_calculateTotal().toStringAsFixed(0)}',
             imageUrl: _data?['image'],
           );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutScreen(
              bookingCode: res['booking_code'],
              serviceType: 'hotel',
            ),
          ),
        );
      } else {
        _snack(res['message'] ?? 'Booking failed', Colors.red);
      }
    } catch (e) {
      setState(() => _submitting = false);
      _snack(e.toString(), Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // UI (Redesigned with Gradient & Style)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_data == null) {
      return const Scaffold(body: Center(child: Text('Hotel not found')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(gradient: kAmbientGradient), // 🟢 Gradient Background
        child: Stack(
          children: [
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
                        _buildConfig(),
                        const SizedBox(height: 16),
                        _buildAvailability(),
                        const SizedBox(height: 24),
                        _sectionTitle('Description'),
                        HtmlWidget(_data!['content'] ?? '', textStyle: const TextStyle(color: Colors.black87, height: 1.5)),
                        const SizedBox(height: 24),
                        _buildFacilities(),
                        const SizedBox(height: 24),
                        _buildHotelServices(),
                        const SizedBox(height: 24),
                        _buildPolicies(),
                        const SizedBox(height: 24),
                        _buildReviews(),
                        const SizedBox(height: 24),
                        _buildRelatedHotels(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------------------

  SliverAppBar _buildSliverAppBar() {
    final gallery = _data!['gallery'];
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
        child: const BackButton(color: Colors.black),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: (gallery is List && gallery.isNotEmpty)
            ? PageView.builder(
                controller: _pageController,
                itemCount: gallery.length,
                onPageChanged: (i) => _currentPage = i,
                itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
              )
            : Image.network(_data!['image'] ?? '', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildHeader() {
    final review = _data!['review_score'];
    final stars = _data!['star_rate'] ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text(
        _data!['title'],
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kHotelSecondary),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          if(stars is int) ...List.generate(stars, (_) => const Icon(Icons.star, size: 18, color: Colors.amber)),
          const SizedBox(width: 8),
          if (_data!['location'] != null) ...[
            const Icon(Icons.location_on, size: 16, color: kHotelPrimary),
            Text(_data!['location']['name'], style: const TextStyle(color: Colors.grey)),
          ]
        ],
      ),
      if (review != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '${review['score_total']} • ${review['score_text']} (${review['total_review']} reviews)',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB36B00)),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _buildConfig() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Row(
          children: [
            Expanded(child: _dateTile('Check In', _startDate, true)),
            Container(width: 1, height: 40, color: Colors.grey[200]),
            Expanded(child: _dateTile('Check Out', _endDate, false)),
          ],
        ),
        const Divider(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _counter('Adults', _adults, (v) => setState(() => _adults = v)),
            _counter('Children', _children, (v) => setState(() => _children = v)),
          ],
        ),
      ]),
    );
  }

  Widget _buildAvailability() {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _checking ? null : _checkAvailability,
          style: ElevatedButton.styleFrom(
            backgroundColor: kHotelPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 5,
            shadowColor: kHotelPrimary.withOpacity(0.4),
          ),
          child: _checking
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('CHECK AVAILABILITY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 20),
      if (_rooms.isNotEmpty) ..._rooms.map(_roomTile),
    ]);
  }

  Widget _roomTile(dynamic room) {
    final id = int.tryParse(room['id'].toString()) ?? 0;
    final qty = _roomQty[id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              room['image'] ?? '',
              width: 80, height: 80, fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(width: 80, height: 80, color: Colors.grey[200]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(room['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('\$${room['price']}', style: const TextStyle(color: kHotelPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('/ night', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          Column(children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: kHotelPrimary),
              onPressed: () => setState(() => _roomQty[id] = qty + 1),
            ),
            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
              onPressed: qty > 0 ? () => setState(() => _roomQty[id] = qty - 1) : null,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildFacilities() {
    final terms = _data!['terms']?['6']?['child'];
    if (terms is! List) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Facilities'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: terms.map<Widget>((e) => Chip(
          label: Text(e['title']),
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade200),
          avatar: const Icon(Icons.check_circle, size: 16, color: kHotelPrimary),
        )).toList(),
      ),
    ]);
  }

  Widget _buildHotelServices() {
    final terms = _data!['terms']?['7']?['child'];
    if (terms is! List) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Services'),
      const SizedBox(height: 8),
      Column(
        children: terms.map<Widget>((e) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: kHotelPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.star_outline, color: kHotelPrimary, size: 20),
          ),
          title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
        )).toList(),
      ),
    ]);
  }

  Widget _buildPolicies() {
    final policies = _data!['policy'];
    if (policies is! List) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Policies'),
      const SizedBox(height: 12),
      ...policies.map((p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: ExpansionTile(
          title: Text(p['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          childrenPadding: const EdgeInsets.all(16),
          children: [Text(p['content'], style: const TextStyle(color: Colors.grey))],
        ),
      )),
    ]);
  }

  Widget _buildReviews() {
    final reviews = _data?['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Guest Reviews'),
      const SizedBox(height: 12),
      SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: reviews.length,
          separatorBuilder: (_,__) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final r = reviews[i];
            final rating = int.tryParse(r['rate_number'].toString()) ?? 5;
            return Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: kHotelPrimary.withOpacity(0.1), child: const Icon(Icons.person, color: kHotelPrimary, size: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r['author']?['name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold))),
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text('$rating', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                Expanded(child: Text(r['content'] ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey))),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildRelatedHotels() {
    final related = _data!['related'];
    if (related is! List) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('You Might Like'),
      const SizedBox(height: 12),
      SizedBox(
        height: 220,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: related.length,
          separatorBuilder: (_,__) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final h = related[i];
            return GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: h['id'], serviceType: 'hotel'))),
              child: Container(
                width: 160,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(h['image'], height: 120, width: double.infinity, fit: BoxFit.cover)),
                  Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h['title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('\$${h['price']}', style: const TextStyle(color: kHotelPrimary, fontWeight: FontWeight.bold)),
                  ]))
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kHotelSecondary));
  }

  Widget _dateTile(String label, DateTime date, bool start) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: date,
        );
        if (d != null) setState(() => start ? _startDate = d : _endDate = d);
      },
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_today, size: 16, color: kHotelPrimary),
          const SizedBox(width: 6),
          Text(DateFormat('MMM dd').format(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _counter(String label, int value, Function(int) onSet) {
    return Column(children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          IconButton(onPressed: value > 0 ? () => onSet(value - 1) : null, icon: const Icon(Icons.remove, size: 18), color: Colors.grey),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(onPressed: () => onSet(value + 1), icon: const Icon(Icons.add, size: 18), color: kHotelPrimary),
        ]),
      ),
    ]);
  }

  Widget _bottomBar() {
    bool canBook = _roomQty.values.any((e) => e > 0);
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\$${_calculateTotal().toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kHotelPrimary)),
              if (canBook) const Text('Total estimate', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: kHotelPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('BOOK NOW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}