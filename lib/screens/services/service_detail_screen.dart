import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';

import '../../services/service_api.dart';
import '../booking/checkout_screen.dart';

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
  // LOAD
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
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // AVAILABILITY
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
    });
  } catch (_) {
    setState(() => _checking = false);
  }
}


  // ---------------------------------------------------------------------------
  // BOOK
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
        body: Center(child: Text('Hotel not found')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildGallery(),
              _buildHeader(),
              _buildConfig(),
              _buildAvailability(),
              _section('Description', HtmlWidget(_data!['content'] ?? '')),
              _buildFacilities(),
              _buildHotelServices(),
              _buildPolicies(),
              _buildReviews(),
              _buildRelatedHotels(),
              const SizedBox(height: 120),
            ],
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------------------------

  Widget _buildGallery() {
    final gallery = _data!['gallery'];
    if (gallery is! List || gallery.isEmpty) {
      return Container(height: 260, color: Colors.grey[300]);
    }

    return SizedBox(
      height: 260,
      child: PageView.builder(
        controller: _pageController,
        itemCount: gallery.length,
        onPageChanged: (i) => _currentPage = i,
        itemBuilder: (_, i) {
          return Image.network(
            gallery[i],
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final review = _data!['review_score'];
    final stars = _data!['star_rate'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _data!['title'],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(
            stars,
            (_) => const Icon(Icons.star, size: 18, color: Colors.amber),
          ),
        ),
        const SizedBox(height: 6),
        if (_data!['location'] != null)
          Row(
            children: [
              const Icon(Icons.location_on, size: 16),
              const SizedBox(width: 4),
              Text(_data!['location']['name']),
            ],
          ),
        const SizedBox(height: 12),
        if (review != null)
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${review['score_total']} • ${review['score_text']} (${review['total_review']} reviews)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ]),
    );
  }

  Widget _buildConfig() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(
            children: [
              Expanded(child: _dateTile('Check in', _startDate, true)),
              Expanded(child: _dateTile('Check out', _endDate, false)),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _counter('Adults', _adults, (v) => setState(() => _adults = v)),
              _counter('Children', _children, (v) => setState(() => _children = v)),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildAvailability() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        ElevatedButton(
          onPressed: _checking ? null : _checkAvailability,
          child: _checking
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('CHECK AVAILABILITY'),
        ),
        const SizedBox(height: 12),
        ..._rooms.map(_roomTile),
      ]),
    );
  }

  Widget _roomTile(dynamic room) {
    final id = int.tryParse(room['id'].toString()) ?? 0;
    final qty = _roomQty[id] ?? 0;

    return Card(
      child: ListTile(
        leading: Image.network(room['image'] ?? '', width: 60, fit: BoxFit.cover),
        title: Text(room['title'] ?? ''),
        subtitle: Text('\$${room['price']}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: qty > 0 ? () => setState(() => _roomQty[id] = qty - 1) : null,
          ),
          Text('$qty'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _roomQty[id] = qty + 1),
          ),
        ]),
      ),
    );
  }

  Widget _buildFacilities() {
    final terms = _data!['terms']?['6']?['child'];
    if (terms is! List) return const SizedBox.shrink();

    return _section(
      'Hotel Facilities',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: terms.map<Widget>((e) => Chip(label: Text(e['title']))).toList(),
      ),
    );
  }

  Widget _buildHotelServices() {
    final terms = _data!['terms']?['7']?['child'];
    if (terms is! List) return const SizedBox.shrink();

    return _section(
      'Hotel Services',
      Column(
        children: terms.map<Widget>((e) => ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(e['title']),
        )).toList(),
      ),
    );
  }

  Widget _buildPolicies() {
    final policies = _data!['policy'];
    if (policies is! List) return const SizedBox.shrink();

    return _section(
      'Rules',
      ExpansionPanelList.radio(
        children: policies.map<ExpansionPanelRadio>((p) {
          return ExpansionPanelRadio(
            value: p['title'],
            headerBuilder: (_, __) => ListTile(title: Text(p['title'])),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(p['content']),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _reviewSummaryBox() {
  final r = _data?['review_score'];
  if (r == null) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Text(
          r['score_total'] ?? '0',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r['score_text'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Based on ${r['total_review']} reviews',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        )
      ],
    ),
  );
}


  Widget _buildReviews() {
    final reviews = _data?['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return _section(
      'Reviews',
      SizedBox(
        height: 230,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: reviews.length,
          itemBuilder: (_, i) {
            final r = reviews[i];
            final rating = int.tryParse(r['rate_number'].toString()) ?? 0;

            return Container(
              width: 320,
              margin: const EdgeInsets.only(right: 14),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['author']?['name'] ?? 'Guest',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(r['content'] ?? ''),
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

  Widget _buildRelatedHotels() {
    final related = _data!['related'];
    if (related is! List) return const SizedBox.shrink();

    return _section(
      'Related Hotels',
      SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: related.length,
          itemBuilder: (_, i) {
            final h = related[i];
            return GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailScreen(
                      serviceId: h['id'],
                      serviceType: 'hotel',
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 160,
                child: Card(
                  child: Column(
                    children: [
                      Image.network(h['image'], height: 100, fit: BoxFit.cover),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          h['title'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _dateTile(String label, DateTime date, bool start) {
    return ListTile(
      title: Text(label),
      subtitle: Text(DateFormat('MMM dd, yyyy').format(date)),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: date,
        );
        if (d != null) {
          setState(() {
            start ? _startDate = d : _endDate = d;
          });
        }
      },
    );
  }

  Widget _counter(String label, int value, Function(int) onSet) {
    return Column(children: [
      Text(label),
      Row(children: [
        IconButton(
          onPressed: value > 0 ? () => onSet(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$value'),
        IconButton(
          onPressed: () => onSet(value + 1),
          icon: const Icon(Icons.add),
        ),
      ]),
    ]);
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: ElevatedButton(
          onPressed: _submitting ? null : _bookNow,
          child: _submitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('BOOK NOW'),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
