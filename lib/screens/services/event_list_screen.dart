// lib/screens/services/event_list_screen.dart
// FIXED: Correct API response handling

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

class EventListScreen extends StatefulWidget {
  EventListScreen({Key? key}) : super(key: key);

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  // STATE
  String? location;
  DateTime? fromDate;
  DateTime? toDate;
  RangeValues priceRange = RangeValues(193, 2000);
  double reviewScore = 0;

  bool isLoading = false;
  List<dynamic> events = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> fetchEvents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Build query parameters - DON'T send price_range by default
      final Map<String, String> queryParams = {};
      
      if (location != null && location!.isNotEmpty) {
        queryParams['s'] = location!;
      }
      
      if (fromDate != null) {
        queryParams['start'] = formatDate(fromDate!);
      }
      
      if (toDate != null) {
        queryParams['end'] = formatDate(toDate!);
      }
      
      // Only add price_range if user has changed it from default
      // Backend expects: price_range=min-max format
      if (priceRange.start != 193 || priceRange.end != 2000) {
        queryParams['price_range'] = 
            '${priceRange.start.round()}-${priceRange.end.round()}';
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}event/search').replace(queryParameters: queryParams);
      
      debugPrint('📡 Fetching events: $uri');
      
      final res = await http.get(uri);

      debugPrint('📥 Response status: ${res.statusCode}');
      debugPrint('📥 Response body: ${res.body}');

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        
        // Handle different response structures
        List<dynamic> eventsList = [];
        
        if (body is Map) {
          // Case 1: {data: {data: [...]}} - Laravel pagination
          if (body['data'] is Map && body['data']['data'] is List) {
            eventsList = body['data']['data'];
          }
          // Case 2: {data: [...]} - Simple array
          else if (body['data'] is List) {
            eventsList = body['data'];
          }
        }
        // Case 3: Response is directly a list
        else if (body is List) {
          eventsList = body;
        }

        debugPrint('✅ Parsed ${eventsList.length} events');

        setState(() {
          events = eventsList;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Server error: ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching events: $e");
      setState(() {
        errorMessage = e.toString();
        events = [];
        isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(context.l10n.eventsTickets),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: context.l10n.searchEventsLocation,
              prefixIcon: Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => location = v,
            onSubmitted: (_) => fetchEvents(),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(fromDate == null ? "From" : formatDate(fromDate!)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: Icon(Icons.calendar_today, size: 16),
                  label: Text(toDate == null ? "To" : formatDate(toDate!)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: fetchEvents,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(Icons.search),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EVENT LIST (TICKET STYLE)
  // ---------------------------------------------------------------------------

  Widget _buildEventList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              context.l10n.errorLoadingEvents,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchEvents,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    if (events.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      onRefresh: fetchEvents,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: events.length,
        itemBuilder: (_, i) => _eventTicketCard(events[i]),
      ),
    );
  }

  Widget _eventTicketCard(dynamic event) {
    final int eventId = int.tryParse(event['id'].toString()) ?? 0;
    final String title = event['title'] ?? 'Untitled Event';
    final String? imageUrl = event['image'];
    final String? duration = event['duration'];
    final String? locationName = event['location']?['name'];
    final dynamic reviewScore = event['review_score'];
    final String? price = event['price']?.toString();
    final String? salePrice = event['sale_price']?.toString();
    final String? discountPercent = event['discount_percent'];

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: eventId),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // IMAGE HEADER
              Stack(
                children: [
                  imageUrl != null
                      ? Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                  Container(
                    height: 180,
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
                  if (salePrice != null && salePrice != '0')
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          discountPercent ?? 'SALE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // CONTENT
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TITLE
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    // INFO ROW
                    Row(
                      children: [
                        if (duration != null)
                          _infoChip(
                            icon: Icons.schedule,
                            text: duration,
                            color: Colors.purple,
                          ),
                        if (duration != null && locationName != null)
                          SizedBox(width: 8),
                        if (locationName != null)
                          Expanded(
                            child: _infoChip(
                              icon: Icons.location_on,
                              text: locationName,
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // RATING & PRICE ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (reviewScore != null)
                          Row(
                            children: [
                              Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                reviewScore['score_total']?.toString() ?? '0',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' (${reviewScore['total_review'] ?? 0})',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (salePrice != null && salePrice != '0')
                              Text(
                                '\$$price',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              '\$${salePrice != null && salePrice != '0' ? salePrice : price}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // TICKET PERFORATION EFFECT
              Container(
                height: 1,
                child: Row(
                  children: List.generate(
                    20,
                    (index) => Expanded(
                      child: Container(
                        height: 1,
                        color: index % 2 == 0
                            ? Colors.grey.shade300
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

              // ACTION BUTTON
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventDetailScreen(eventId: eventId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6C5CE7),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      context.l10n.getTickets,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[300],
      child: Icon(Icons.event, size: 64, color: Colors.grey),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            context.l10n.noEventsFound,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            context.l10n.tryAdjustingYourSearchFilters,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                location = null;
                fromDate = null;
                toDate = null;
                priceRange = RangeValues(193, 2000);
              });
              fetchEvents();
            },
            child: Text(context.l10n.clearFilters),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.filters,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
                "Price: \$${priceRange.start.round()} - \$${priceRange.end.round()}"),
            RangeSlider(
              min: 193,
              max: 2000,
              values: priceRange,
              onChanged: (v) => setState(() => priceRange = v),
            ),
            SizedBox(height: 16),
            Text("Review Score: ${reviewScore.round()} stars"),
            Slider(
              min: 0,
              max: 5,
              divisions: 5,
              value: reviewScore,
              onChanged: (v) => setState(() => reviewScore = v),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  fetchEvents();
                },
                child: Text(context.l10n.applyFilters),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => isFrom ? fromDate = date : toDate = date);
    }
  }
}