// lib/screens/services/event_detail_screen.dart
// IMPROVED: Modern ticket-style detail screen with guest booking

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../booking/event_checkout_screen.dart';

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
  DateTime? _selectedDate;
  final Map<String, int> _ticketCounts = {};
  final Map<String, int> _extraCounts = {};

  @override
  void initState() {
    super.initState();
    _future = _fetchEventDetail();
  }

  Future<Map<String, dynamic>> _fetchEventDetail() async {
    final res = await http.get(
      Uri.parse('https://megatour.vn/api/event/detail/${widget.eventId}'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load event');
    }

    final jsonData = json.decode(res.body);
    return jsonData['data'];
  }

  // ---------------------------------------------------------------------------
  // BOOK NOW
  // ---------------------------------------------------------------------------

  void _bookNow() {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event date')),
      );
      return;
    }

    final hasTickets = _ticketCounts.values.any((c) => c > 0);
    if (!hasTickets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one ticket')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventCheckoutScreen(
          eventId: widget.eventId,
          selectedDate: _selectedDate!,
          ticketCounts: Map.from(_ticketCounts),
          extraCounts: Map.from(_extraCounts),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
            return const Center(child: Text("Error loading event"));
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
                        _buildEventInfo(event),
                        _buildTicketSelection(event),
                        _buildDescription(event),
                        _buildExtraServices(event),
                        _buildReviews(event),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
              _buildBackButton(),
            ],
          );
        },
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTIONS
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar(Map<String, dynamic> event) {
    return SliverAppBar(
      expandedHeight: 300,
      automaticallyImplyLeading: false,
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> event) {
    final review = event['review_score'];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CATEGORY
          if (event['terms'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'EVENT',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // TITLE
          Text(
            event['title'] ?? '',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // LOCATION
          if (event['location'] != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.blue),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event['location']['name'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // RATING
          if (review != null)
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${review['score_total']} ${review['score_text']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  ' • ${review['total_review']} reviews',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEventInfo(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _infoBox(
            icon: Icons.schedule,
            title: 'Duration',
            value: event['duration'] ?? 'N/A',
          ),
          const SizedBox(width: 12),
          _infoBox(
            icon: Icons.access_time,
            title: 'Start Time',
            value: event['start_time'] ?? 'All Day',
          ),
        ],
      ),
    );
  }

  Widget _infoBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketSelection(Map<String, dynamic> event) {
    final tickets = event['ticket_types'] as List? ?? [];
    if (tickets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Tickets',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // DATE PICKER
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month, color: Colors.blue),
            title: Text(
              _selectedDate == null
                  ? 'Select event date'
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
            ),
            trailing: const Icon(Icons.edit),
            tileColor: Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _selectedDate = date);
            },
          ),

          const SizedBox(height: 16),

          // TICKETS
          ...tickets.map((ticket) {
            final code = ticket['code'];
            final count = _ticketCounts[code] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${ticket['price']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: count > 0
                                ? () => setState(() =>
                                    _ticketCounts[code] = count - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                          ),
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() =>
                                _ticketCounts[code] = count + 1),
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDescription(Map<String, dynamic> event) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Event',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          HtmlWidget(event['content'] ?? 'No description available.'),
        ],
      ),
    );
  }

  Widget _buildExtraServices(Map<String, dynamic> event) {
    final extras = event['extra_price'] as List? ?? [];
    if (extras.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extra Services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...extras.map((extra) {
            final name = extra['name'];
            final count = _extraCounts[name] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '\$${extra['price']}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: count > 0
                            ? () => setState(() =>
                                _extraCounts[name] = count - 1)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$count'),
                      IconButton(
                        onPressed: () => setState(() =>
                            _extraCounts[name] = count + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildReviews(Map<String, dynamic> event) {
    final reviews = event['review_lists']?['data'] as List? ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...reviews.take(3).map((r) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < (int.tryParse(r['rate_number'].toString()) ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r['content'] ?? '',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _bookNow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C5CE7),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Book Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}