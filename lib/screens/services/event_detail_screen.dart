import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchEventDetail();
  }

  Future<Map<String, dynamic>> _fetchEventDetail() async {
    // Correctly using widget.eventId to access constructor data
    final res = await http.get(
      Uri.parse('https://megatour.vn/api/event/detail/${widget.eventId}'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load event data');
    }

    final jsonData = json.decode(res.body);
    return jsonData['data'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Error loading event details"));
          }

          final event = snapshot.data!;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildAppBar(event),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(event),
                        _buildInfoRow(event),
                        _buildDivider(),
                        _buildContent(event),
                        _buildDivider(),
                        _buildExtraPrices(event),
                        _buildDivider(),
                        _buildReviews(event),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
              // BACK BUTTON
              Positioned(
                top: 50,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
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

  // ============================================================
  // APP BAR (BANNER)
  // ============================================================
  SliverAppBar _buildAppBar(Map<String, dynamic> event) {
    return SliverAppBar(
      expandedHeight: 300,
      automaticallyImplyLeading: false, // Hidden because we use custom back button
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              event['banner_image'] ?? event['image'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey),
            ),
            Container(color: Colors.black.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER (TITLE/RATING)
  // ============================================================
  Widget _buildHeader(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event['title'] ?? 'Event Detail',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (event['address'] != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event['address'],
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text(
                '${event['review_score']?['score_total'] ?? '0'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                ' (${event['review_score']?['total_review'] ?? 0} reviews)',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW (DURATION/LOCATION)
  // ============================================================
  Widget _buildInfoRow(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoItem(Icons.schedule, event['duration'] ?? 'N/A'),
          _infoItem(Icons.access_time, event['start_time'] ?? 'All Day'),
          _infoItem(Icons.place, event['location']?['name'] ?? 'Virtual'),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blueAccent),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ============================================================
  // DESCRIPTION
  // ============================================================
  Widget _buildContent(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            _stripHtml(event['content'] ?? 'No description available.'),
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXTRA PRICES
  // ============================================================
  Widget _buildExtraPrices(Map<String, dynamic> event) {
    final extras = event['extra_price'] as List? ?? [];
    if (extras.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Extra Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...extras.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e['name'] ?? ''),
                    Text('\$${e['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ============================================================
  // REVIEWS
  // ============================================================
  Widget _buildReviews(Map<String, dynamic> event) {
    final reviews = event['review_lists']?['data'] as List? ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...reviews.take(3).map((r) => Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text('${r['rate_number']}/5', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(r['content'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR (PRICE & BOOKING)
  // ============================================================
  Widget _buildBottomBar(Map<String, dynamic> event) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Starting from', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
                '\$${event['price'] ?? '0'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              // Action for booking
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Book Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 40, thickness: 1, color: Colors.grey.shade100);

  String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '');
}