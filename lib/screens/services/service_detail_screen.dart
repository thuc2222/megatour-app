import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../services/service_api.dart';
import '../booking/checkout_screen.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;
  final String serviceType;

  const ServiceDetailScreen({
    Key? key,
    required this.serviceId,
    required this.serviceType,
  }) : super(key: key);

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final ServiceApi _api = ServiceApi();
  final PageController _galleryController = PageController();

  Map<String, dynamic>? _data;
  List<dynamic> _rooms = [];
  List<dynamic> _reviews = [];
  Map<int, int> _selectedRoomCounts = {};

  bool _isLoading = true;
  bool _isCheckingAvailability = false;
  bool _isSubmitting = false;

  int _currentGalleryIndex = 0;

  int _adults = 2;
  int _children = 0;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadReviews();

    Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_galleryController.hasClients) return;
      final total = _getSafeGallery().length;
      if (total <= 1) return;

      final next = (_currentGalleryIndex + 1) % total;
      _galleryController.animateToPage(
        next,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _loadData() async {
    try {
      final res = await _api.getServiceDetailRaw(
        id: widget.serviceId,
        serviceType: widget.serviceType,
      );
      if (!mounted) return;

      setState(() {
        _data = res['data'] ?? {};
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final data = await _api.getReviews(
        serviceId: widget.serviceId,
        serviceType: widget.serviceType,
      );
      if (mounted) setState(() => _reviews = data);
    } catch (_) {}
  }

  Future<void> _checkAvailability() async {
    setState(() => _isCheckingAvailability = true);

    try {
      final res = await _api.checkAvailability(
        id: widget.serviceId,
        serviceType: widget.serviceType,
        start: DateFormat('yyyy-MM-dd').format(_startDate!),
        end: DateFormat('yyyy-MM-dd').format(_endDate!),
        adults: _adults,
        children: _children,
      );

      if (!mounted) return;

      final data = res?['data'];
      setState(() {
        _rooms = data is List
            ? data
            : data is Map
                ? data.values.toList()
                : [];
        _isCheckingAvailability = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
  }

  Future<void> _submitBooking() async {
    if (_selectedRoomCounts.values.every((v) => v == 0)) {
      _snack('Please select at least one room.', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _api.createBooking(
        objectModel: widget.serviceType,
        objectId: widget.serviceId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        adults: _adults,
        children: _children,
        items: _selectedRoomCounts,
      );

      setState(() => _isSubmitting = false);

      if (res is Map && res['status'] == 1) {
        final String bookingCode = res['booking_code'];

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutScreen(
              bookingCode: bookingCode,
              serviceType: widget.serviceType,
            ),
          ),
        );
      } else {
        _snack(res['message'] ?? 'Booking failed', Colors.red);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _snack(e.toString(), Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // SAFE HELPERS
  // ---------------------------------------------------------------------------

  List<String> _getSafeGallery() {
    final g = _data?['gallery'];
    final list = <String>[];

    if (g is List) {
      for (final i in g) {
        if (i is String) list.add(i);
        if (i is Map && i['large'] != null) list.add(i['large']);
      }
    }

    if (list.isEmpty && _data?['image'] != null) {
      list.add(_data!['image']);
    }

    return list;
  }

  List<dynamic> _getSafeList(String key) {
    final d = _data?[key];
    if (d is List) return d;
    if (d is Map) return d.values.toList();
    return [];
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildGallery(),
              SliverToBoxAdapter(child: _buildBody()),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    final images = _getSafeGallery();

    return SliverAppBar(
      expandedHeight: 320,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: PageView.builder(
          controller: _galleryController,
          itemCount: images.length,
          onPageChanged: (i) => _currentGalleryIndex = i,
          itemBuilder: (_, i) => Image.network(images[i], fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildConfigCard(),
          _buildAvailabilitySection(),
          _section('Description', HtmlWidget(_data?['content'] ?? '')),
          _section('Amenities', _buildFacilitiesGrid()),
          _section('Reviews', _buildReviewList()),
          _section('Related Stays', _buildRelatedHotels()),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildHeader() => Text(
        _data?['title'] ?? '',
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      );

  Widget _buildConfigCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _counter('Adults', _adults, (v) => setState(() => _adults = v)),
            _counter('Children', _children, (v) => setState(() => _children = v)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(
                '${DateFormat('MMM dd').format(_startDate!)} → ${DateFormat('MMM dd').format(_endDate!)}',
              ),
              onTap: _selectDates,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isCheckingAvailability ? null : _checkAvailability,
          child: _isCheckingAvailability
              ? const CircularProgressIndicator()
              : const Text('CHECK AVAILABILITY'),
        ),
        ..._rooms.map(_buildRoomTile),
      ],
    );
  }

  Widget _buildRoomTile(dynamic room) {
    final id = int.tryParse(room['id'].toString()) ?? 0;
    final count = _selectedRoomCounts[id] ?? 0;

    return ListTile(
      title: Text(room['title'] ?? ''),
      subtitle: Text('\$${room['price']}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: count > 0
                ? () => setState(() => _selectedRoomCounts[id] = count - 1)
                : null,
          ),
          Text('$count'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () =>
                setState(() => _selectedRoomCounts[id] = count + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    if (_reviews.isEmpty) return const Text('No reviews yet');
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _reviews
            .map((r) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(r['content'] ?? ''),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildRelatedHotels() {
    final related = _getSafeList('related');
    if (related.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: related.length,
        itemBuilder: (_, i) {
          final item = related[i];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceDetailScreen(
                    serviceId: int.tryParse(item['id'].toString()) ?? 0,
                    serviceType: widget.serviceType,
                  ),
                ),
              );
            },
            child: Card(
              child: SizedBox(
                width: 140,
                child: Column(
                  children: [
                    Image.network(item['image'] ?? '', height: 80),
                    Text(item['title'] ?? ''),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitBooking,
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('BOOK NOW'),
        ),
      ),
    );
  }

  Widget _counter(String label, int v, Function(int) set) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(onPressed: () => set(v > 0 ? v - 1 : 0), icon: const Icon(Icons.remove)),
            Text('$v'),
            IconButton(onPressed: () => set(v + 1), icon: const Icon(Icons.add)),
          ],
        ),
      ],
    );
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFacilitiesGrid() {
    final terms = _getSafeList('terms');
    return Wrap(
      spacing: 8,
      children: terms.map((t) => Chip(label: Text(t['name'] ?? ''))).toList(),
    );
  }

  void _selectDates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (r != null) setState(() {
      _startDate = r.start;
      _endDate = r.end;
    });
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }
}
