import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../services/service_api.dart';
import '../booking/checkout_screen.dart';

class TourDetailScreen extends StatefulWidget {
  final int tourId;

  const TourDetailScreen({Key? key, required this.tourId}) : super(key: key);

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final ServiceApi _api = ServiceApi();

  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  DateTime? _selectedDate;
  final Map<String, int> _personCounts = {};
  final Set<int> _selectedExtras = {};

  final PageController _pageController = PageController();
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadTour();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTour() async {
    try {
      final res = await _api.getServiceDetailRaw(
        id: widget.tourId,
        serviceType: 'tour',
      );

      Map<String, dynamic> safeData = {};
      if (res is Map<String, dynamic>) {
        final raw = res['data'];
        if (raw is Map<String, dynamic>) {
          safeData = raw;
        }
      }

      _data = safeData;
      _initPersons();
      _startAutoSlide();

      setState(() => _loading = false);
    } catch (_) {
      setState(() => _loading = false);
    }
  }


  void _initPersons() {
    final persons = _data?['person_types'];
    if (persons is List) {
      for (final p in persons) {
        _personCounts[p['name']] =
            int.tryParse(p['min'].toString()) ?? 0;
      }
    }
  }

  void _startAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length < 2) return;

    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!_pageController.hasClients) return;
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
  // BOOK TOUR (FIXED)
  // ---------------------------------------------------------------------------

  Future<void> _bookNow() async {
  if (_selectedDate == null) {
    _snack('Please select tour date', Colors.orange);
    return;
  }

  setState(() => _submitting = true);

  try {
    final start = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final end = DateFormat('yyyy-MM-dd')
        .format(_selectedDate!.add(const Duration(days: 1)));
    final res = await _api.createBooking(
      objectModel: 'tour',
      objectId: widget.tourId,
      startDate: start,
      endDate: end,
      adults: _personCounts.values.fold(0, (sum, count) => sum + count), // Total count
      personTypes: _personCounts, // Pass the actual person counts
      items: {0: 1}, // Required by API
    );

    setState(() => _submitting = false);

    if (res is Map && res['status'] == 1 && res['booking_code'] != null) {
      final String bookingCode = res['booking_code'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            bookingCode: bookingCode,
            serviceType: 'tour',
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
  // UI (UNCHANGED)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildGallery(),
              _buildSummary(),
              _buildBookingPanel(),
              _buildSection('Overview', HtmlWidget(_data?['content'] ?? '')),
              _buildItinerary(),
              _buildIncludeExclude(),
              _buildFAQs(),
              _buildReviews(),
              _buildRelatedTours(),
              const SizedBox(height: 120),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------------------------

  Widget _buildGallery() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.isEmpty) {
      return const SizedBox(height: 260);
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

  Widget _buildSummary() {
    final review = _data?['review_score'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _data?['title'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (_data?['location'] != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Text(_data!['location']['name']),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (review != null)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${review['score_total']} (${review['total_review']} reviews)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_data?['price'] != null)
                    Text(
                      '\$${_data?['price']}',
                      style: const TextStyle(
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    '\$${_data?['sale_price'] ?? _data?['price']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingPanel() {
    final persons = _data?['person_types'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // DATE
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month),
              title: Text(
                _selectedDate == null
                    ? 'Select tour date'
                    : DateFormat('MMM dd, yyyy').format(_selectedDate!),
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            const Divider(),

            // PERSON TYPES
            if (persons is List)
              ...persons.map<Widget>((p) {
                final name = p['name'];
                final count = _personCounts[name] ?? 0;
                final max =
                    int.tryParse(p['max'].toString()) ?? 99;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(name),
                  subtitle: Text('Age: ${p['desc']} • \$${p['price']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: count > 0
                            ? () => setState(() =>
                                _personCounts[name] = count - 1)
                            : null,
                      ),
                      Text('$count'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: count < max
                            ? () => setState(() =>
                                _personCounts[name] = count + 1)
                            : null,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildItinerary() {
  final list = _data?['itinerary'];
  if (list is! List || list.isEmpty) return const SizedBox.shrink();

  return _buildSection(
    'Itinerary',
    SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        itemBuilder: (_, i) {
          final day = list[i];

          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: Image.network(
                      day['image'],
                      fit: BoxFit.cover,
                    ),
                  ),

                  // CONTENT
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day['title'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day['desc'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 🔑 SCROLLABLE CONTENT
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Text(
                                day['content'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
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
  );
}


  Widget _buildIncludeExclude() {
    final inc = _data?['include'];
    final exc = _data?['exclude'];

    return _buildSection(
      'Included / Excluded',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Included',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...?inc?.map<Widget>(
                    (e) => Text('• ${e['title']}')),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Excluded',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...?exc?.map<Widget>(
                    (e) => Text('• ${e['title']}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQs() {
    final faqs = _data?['faqs'];
    if (faqs is! List) return const SizedBox.shrink();

    return _buildSection(
      'FAQs',
      ExpansionPanelList.radio(
        children: faqs.map<ExpansionPanelRadio>((f) {
          return ExpansionPanelRadio(
            value: f['title'],
            headerBuilder: (_, __) => ListTile(title: Text(f['title'])),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(f['content']),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviews() {
  final reviews = _data?['review_lists']?['data'];

  if (reviews is! List || reviews.isEmpty) {
    return const SizedBox.shrink();
  }

  return _buildSection(
    'Reviews',
    SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: reviews.length,
        itemBuilder: (_, i) {
          final r = reviews[i];
          final author = r['author'] ?? {};
          final rating = int.tryParse(r['rate_number'].toString()) ?? 0;

          final name = author['name'] ?? 'Guest';
          final avatar = author['avatar'] ??
              'https://megatour.vn/images/avatar.png';

          return Container(
            width: 320,
            margin: const EdgeInsets.only(right: 14),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (r['created_at'] != null)
                                Text(
                                  r['created_at']
                                      .toString()
                                      .split('T')
                                      .first,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // STARS
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.orange,
                          size: 18,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // TITLE
                    if (r['title'] != null)
                      Text(
                        r['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),

                    const SizedBox(height: 6),

                    // CONTENT (SCROLL SAFE)
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
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


  Widget _buildRelatedTours() {
  final related = _data?['related'];
  if (related is! List || related.isEmpty) {
    return const SizedBox.shrink();
  }

  return _buildSection(
    'Related Tours',
    SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: related.length,
        itemBuilder: (_, i) {
          final t = related[i];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TourDetailScreen(
                    tourId: t['id'],
                  ),
                ),
              );
            },
            child: Container(
              width: 200,
              margin: const EdgeInsets.only(right: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.network(
                      t['image'],
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t['title'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (t['review_score'] != null)
                            Text(
                              '⭐ ${t['review_score']['score_total']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
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


  Widget _buildBottomBar() {
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
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _bookNow,
            child: _submitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('BOOK NOW'),
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
