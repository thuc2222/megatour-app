import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../services/service_api.dart';
import '../booking/checkout_webview.dart';

class ServiceDetailScreen extends StatefulWidget {
  final int serviceId;
  final String serviceType;

  const ServiceDetailScreen({Key? key, required this.serviceId, required this.serviceType}) : super(key: key);

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

  // Configuration State
  int _adults = 2;
  int _children = 0;
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadReviews();
    // Auto-slide Gallery
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_galleryController.hasClients) {
        int next = _currentGalleryIndex + 1;
        int total = _getSafeGallery().length;
        if (next >= total) next = 0;
        _galleryController.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  // --- API LOGIC ---

  Future<void> _loadData() async {
    try {
      final response = await _api.getServiceDetailRaw(id: widget.serviceId, serviceType: widget.serviceType);
      if (mounted) {
        setState(() {
          _data = (response is Map && response['data'] != null) ? response['data'] : {};
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAvailability() async {
  setState(() => _isCheckingAvailability = true);

  try {
    final result = await _api.checkAvailability(
      id: widget.serviceId,
      serviceType: widget.serviceType,
      start: DateFormat('yyyy-MM-dd').format(_startDate!),
      end: DateFormat('yyyy-MM-dd').format(_endDate!),
      adults: _adults,
      children: _children,
    );

    if (!mounted) return;

    final data = result?['data'];

    setState(() {
      if (data is List) {
        _rooms = data;
      } else if (data is Map) {
        _rooms = data.values.toList();
      } else {
        _rooms = [];
      }
      _isCheckingAvailability = false;
    });
  } catch (e) {
    if (mounted) {
      setState(() => _isCheckingAvailability = false);
    }
  }
}


    Future<void> _submitBooking() async {
    // 1️⃣ Basic validation
    if (_selectedRoomCounts.isEmpty ||
        !_selectedRoomCounts.values.any((v) => v > 0)) {
      _showSnackBar("Please select at least one room.", Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 2️⃣ Build items map (only rooms with qty > 0)
      final items = <String, dynamic>{};
      _selectedRoomCounts.forEach((roomId, qty) {
        if (qty > 0) {
          items[roomId.toString()] = {'number': qty};
        }
      });

      // 3️⃣ Call API
      final response = await _api.createBooking(
        objectModel: widget.serviceType,
        objectId: widget.serviceId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        adults: _adults,
        children: _children,
        items: _selectedRoomCounts,
      );

      setState(() => _isSubmitting = false);

      // 4️⃣ Handle response
      if (response is Map && response['status'] == 1) {
        if (response['status'] == 1) {
  final bookingCode = response['booking_code'];

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CheckoutWebView(
        bookingCode: bookingCode,
      ),
    ),
  );
} else {
  _showSnackBar(
    response['message'] ?? 'Booking failed',
    Colors.red,
  );
}

      } else {
        _showSnackBar(
          response['message'] ?? 'Booking failed',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnackBar('Booking error: $e', Colors.red);
    }
  }


  // --- SAFE PARSERS (Preventing String/Map errors) ---

  List<String> _getSafeGallery() {
    var galleryData = _data?['gallery'];
    List<String> list = [];
    if (galleryData is List) {
      for (var item in galleryData) {
        if (item is String) list.add(item);
        else if (item is Map) list.add(item['large'] ?? "");
      }
    } else if (galleryData is Map) {
      galleryData.forEach((k, v) => list.add(v is Map ? v['large'] : v.toString()));
    }
    if (list.isEmpty && _data?['image'] != null) list.add(_data!['image']);
    return list;
  }

  List<dynamic> _getSafeList(String key) {
    var data = _data?[key];
    if (data is List) return data;
    if (data is Map) return data.values.toList();
    return [];
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9))));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverGallery(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      _buildConfigCard(),
                      _buildAvailabilitySection(),
                      _buildSectionTitle("Description"),
                      _buildContentDetail(),
                      _buildSectionTitle("Amenities"),
                      _buildFacilitiesGrid(),
                      _buildMapSection(),
                      _buildSectionTitle("Guest Reviews"),
                      _buildReviewList(),
                      _buildSectionTitle("Related Stays"),
                      _buildRelatedHotels(),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomActionNav(),
        ],
      ),
    );
  }

  Widget _buildSliverGallery() {
    final images = _getSafeGallery();
    return SliverAppBar(
      expandedHeight: 320,
      elevation: 0,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _galleryController,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _currentGalleryIndex = i),
              itemBuilder: (context, i) => Image.network(images[i], fit: BoxFit.cover),
            ),
            Positioned(
              bottom: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text("${_currentGalleryIndex + 1} / ${images.length}", style: const TextStyle(color: Colors.white, fontSize: 10)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    double score = double.tryParse(_data?['review_score']?.toString() ?? "5") ?? 5.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("PREMIUM ${widget.serviceType.toUpperCase()}", style: TextStyle(color: Colors.cyan[700], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, color: i < score.floor() ? Colors.amber : Colors.grey[200], size: 18))),
          ],
        ),
        const SizedBox(height: 8),
        Text(_data?['title'] ?? "", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildConfigCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _counter("Adults", _adults, (v) => setState(() => _adults = v)),
              _counter("Children", _children, (v) => setState(() => _children = v)),
            ],
          ),
          const Divider(height: 30),
          InkWell(
            onTap: _selectDates,
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 12),
                Text("${DateFormat('MMM dd').format(_startDate!)} — ${DateFormat('MMM dd').format(_endDate!)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: _isCheckingAvailability ? null : _checkAvailability,
            child: _isCheckingAvailability ? const CircularProgressIndicator(color: Colors.white) : const Text("CHECK AVAILABILITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        if (_rooms.isNotEmpty) ...[
          const SizedBox(height: 20),
          ..._rooms.map((room) => _buildRoomTile(room)).toList(),
        ]
      ],
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
  final int roomId = int.tryParse(room['id'].toString()) ?? 0;
  final int selected = _selectedRoomCounts[roomId] ?? 0;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------------
        // IMAGE
        // ---------------------------------------------------------------------
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            room['image'] ?? '',
            width: 90,
            height: 90,
            fit: BoxFit.cover,
          ),
        ),

        const SizedBox(width: 14),

        // ---------------------------------------------------------------------
        // ROOM INFO
        // ---------------------------------------------------------------------
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                room['title'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 6),

              // Meta info row
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _roomMeta(Icons.square_foot, room['size_html']),
                  _roomMeta(Icons.bed_outlined, room['beds_html']),
                  _roomMeta(Icons.person_outline, room['adults_html']),
                  _roomMeta(Icons.child_care_outlined, room['children_html']),
                ],
              ),

              const SizedBox(height: 10),

              // Price + availability
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "\$${room['price']}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                  Text(
                    "${room['number']} left",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---------------------------------------------------------------------
        // COUNTER
        // ---------------------------------------------------------------------
        Column(
          children: [
            _qtyButton(
              icon: Icons.add,
              onTap: () {
                setState(() {
                  _selectedRoomCounts[roomId] = selected + 1;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                "$selected",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            _qtyButton(
              icon: Icons.remove,
              onTap: selected > 0
                  ? () {
                      setState(() {
                        _selectedRoomCounts[roomId] = selected - 1;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ],
    ),
  );
}
Widget _roomMeta(IconData icon, String? text) {
  if (text == null || text.isEmpty) return const SizedBox.shrink();
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
    ],
  );
}

Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: onTap == null ? Colors.grey[200] : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: onTap == null ? Colors.grey : const Color(0xFF0EA5E9),
      ),
    ),
  );
}


  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Location"),
        Container(
          height: 180, width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: Colors.grey[200]),
          child: const Center(child: Icon(Icons.map_outlined, size: 40, color: Colors.grey)),
        ),
      ],
    );
  }

  Future<void> _loadReviews() async {
  try {
    final data = await _api.getReviews(
      serviceId: widget.serviceId,
      serviceType: widget.serviceType,
    );

    if (mounted) {
      setState(() => _reviews = data);
    }
  } catch (_) {}
}

  Widget _buildReviewList() {
  if (_reviews.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        "No reviews yet",
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }

  return SizedBox(
    height: 150,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _reviews.length,
      itemBuilder: (context, i) {
        final r = _reviews[i];
        final int rating = r['rate_number'] ?? 0;

        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⭐ Rating
              Row(
                children: List.generate(
                  5,
                  (idx) => Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: idx < rating
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Title
              Text(
                r['title'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 6),

              // Content
              Text(
                r['content'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}


  Widget _buildRelatedHotels() {
  final related = _getSafeList('related');

  if (related.isEmpty) {
    return const SizedBox.shrink();
  }

  return SizedBox(
    height: 190,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: related.length,
      itemBuilder: (context, i) {
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
          child: Container(
            width: 150,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    item['image'] ?? '',
                    height: 100,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 8),

                // Title
                Text(
                  item['title'] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                // Price
                Text(
                  "\$${item['price'] ?? ''}",
                  style: TextStyle(
                    color: Colors.cyan[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}


  // --- REUSABLE WIDGETS ---

  Widget _counter(String label, int val, Function(int) onSet) => Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    Row(children: [
      IconButton(onPressed: () => onSet(val > 0 ? val - 1 : 0), icon: const Icon(Icons.remove_circle_outline, size: 20)),
      Text("$val", style: const TextStyle(fontWeight: FontWeight.bold)),
      IconButton(onPressed: () => onSet(val + 1), icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0EA5E9))),
    ])
  ]);

  Widget _roomCounter(int id) => Row(children: [
    IconButton(onPressed: () => setState(() => _selectedRoomCounts[id] = (_selectedRoomCounts[id] ?? 0) > 0 ? _selectedRoomCounts[id]! - 1 : 0), icon: const Icon(Icons.remove, size: 16)),
    Text("${_selectedRoomCounts[id] ?? 0}"),
    IconButton(onPressed: () => setState(() => _selectedRoomCounts[id] = (_selectedRoomCounts[id] ?? 0) + 1), icon: const Icon(Icons.add, size: 16, color: Color(0xFF0EA5E9))),
  ]);

  Widget _buildSectionTitle(String title) => Padding(padding: const EdgeInsets.only(top: 30, bottom: 15), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));

  Widget _buildContentDetail() => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: HtmlWidget(_data?['content'] ?? ""));

  Widget _buildFacilitiesGrid() {
    final terms = _getSafeList('terms');
    return Wrap(spacing: 8, runSpacing: 8, children: terms.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.cyan[50], borderRadius: BorderRadius.circular(8)), child: Text(t['name'] ?? "", style: TextStyle(color: Colors.cyan[800], fontSize: 11, fontWeight: FontWeight.bold)))).toList());
  }

  Widget _buildBottomActionNav() => Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.fromLTRB(25, 20, 25, 40), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))), child: Row(children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      const Text("PRICE STARTING", style: TextStyle(fontSize: 10, color: Colors.grey)),
      Text("\$${_data?['price'] ?? '0'}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    ]),
    const Spacer(),
    SizedBox(height: 56, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 40)), onPressed: _isSubmitting ? null : _submitBooking, child: _isSubmitting ? const CircularProgressIndicator() : const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
  ])));

  void _selectDates() async {
    final range = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF0EA5E9))), child: child!));
    if (range != null) setState(() { _startDate = range.start; _endDate = range.end; });
  }

  void _showSnackBar(String msg, Color color) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  
  void _showSuccessDialog() => showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Success"), content: const Text("Your booking has been received."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
}