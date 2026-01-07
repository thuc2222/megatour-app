import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:megatour_app/utils/context_extension.dart';

// =============================================================================
// 1. THEME CONSTANTS
// =============================================================================
const Color kEventDark = Color(0xFF1A1A2E);
const Color kEventPurple = Color(0xFF6C5CE7);
const Color kEventPink = Color(0xFFE84393);
const Color kEventSurface = Color(0xFFF8F9FA);

// =============================================================================
// 2. EVENT DETAIL SCREEN
// =============================================================================
class EventDetailScreen extends StatefulWidget {
  final int eventId;
  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  Map<String, dynamic>? _eventData;
  List<Map<String, dynamic>> _ticketTypes = [];
  Map<String, int> _ticketCounts = {};
  
  bool _loading = true;
  bool _submitting = false;
  DateTime? _selectedDate;
  
  final PageController _galleryController = PageController();
  Timer? _galleryTimer;
  int _currentGalleryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _galleryController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadEvent() async {
    try {
      final res = await http.get(
        Uri.parse('https://megatour.vn/api/event/detail/${widget.eventId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final data = json['data'];
        final tickets = List<Map<String, dynamic>>.from(data['ticket_types'] ?? []);

        if (mounted) {
          setState(() {
            _eventData = data;
            _ticketTypes = tickets;
            for (final t in tickets) {
              _ticketCounts[t['code']] = 0;
            }
            _loading = false;
          });
          _startAutoSlide();
        }
      } else {
        throw Exception('Failed to load event');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint("Error loading event: $e");
    }
  }

  void _startAutoSlide() {
    final gallery = _eventData?['gallery'];
    if (gallery is! List || gallery.length < 2) return;
    
    _galleryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _currentGalleryIndex = (_currentGalleryIndex + 1) % gallery.length;
      if (_galleryController.hasClients) {
        _galleryController.animateToPage(
          _currentGalleryIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  double _calculateTotal() {
    double total = 0;
    for (var t in _ticketTypes) {
      final price = double.tryParse('${t['price']}') ?? 0;
      final count = _ticketCounts[t['code']] ?? 0;
      total += price * count;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // BOOKING LOGIC (UPDATED: Add to Cart Here)
  // ---------------------------------------------------------------------------
  Future<void> _bookNow() async {
    if (_selectedDate == null) return _snack('Please select an event date', Colors.orange);
    if (!_ticketCounts.values.any((c) => c > 0)) return _snack('Select at least one ticket', Colors.orange);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return _snack('Please login to book', Colors.red);

    setState(() => _submitting = true);

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      // Construct Payload with Indexed Ticket Types
      // Example: ticket_types[0][code] = vip, ticket_types[0][number] = 2
      final Map<String, String> body = {
        'service_id': widget.eventId.toString(),
        'service_type': 'event',
        'start_date': startStr,
      };

      int index = 0;
      _ticketCounts.forEach((code, count) {
        if (count > 0) {
          body['ticket_types[$index][code]'] = code;
          body['ticket_types[$index][number]'] = count.toString();
          // Optional: Some backends might need price/name repeated, but usually ID/Number is enough
          index++;
        }
      });

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
                 builder: (_) => EventCheckoutScreen(
                   bookingCode: code!,
                   eventTitle: _eventData?['title'] ?? 'Event',
                   date: _selectedDate!,
                   total: _calculateTotal(),
                 ),
               ),
             );
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
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_eventData == null) return const Scaffold(body: Center(child: Text('Event not found')));

    return Scaffold(
      backgroundColor: kEventSurface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeaderInfo(),
                    _buildTicketSection(), 
                    _buildSpecs(),
                    _buildDescription(),
                    _buildFAQs(),
                    _buildReviews(),
                    _buildRelatedEvents(),
                    const SizedBox(height: 120),
                  ],
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

  SliverAppBar _buildAppBar() {
    final gallery = _eventData!['gallery'] as List? ?? [];
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: kEventDark,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
          child: IconButton(
            icon: Icon(_eventData!['is_wishlist'] == 1 ? Icons.favorite : Icons.favorite_border, color: kEventPink),
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
                  controller: _galleryController,
                  itemCount: gallery.length,
                  itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
                )
              : Image.network(_eventData!['image'] ?? '', fit: BoxFit.cover),
            
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.transparent, kEventDark.withOpacity(0.9)],
                ),
              ),
            ),
            
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_eventData!['location'] != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: kEventPink, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          _eventData!['location']['name'],
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _eventData!['title'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final review = _eventData!['review_score'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kEventPurple.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.event, color: kEventPurple),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_eventData!['start_time'] ?? 'TBA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(_eventData!['duration'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (review != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(review['score_total'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Text('${review['total_review']} reviews', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTicketSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Date Selector
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: _selectedDate ?? DateTime.now());
              if (d != null) setState(() => _selectedDate = d);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kEventPurple, kEventPink]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [BoxShadow(color: kEventPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DATE", style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                      Text(
                        _selectedDate == null ? "Select Date" : DateFormat('EEE, d MMM yyyy').format(_selectedDate!),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const Icon(Icons.calendar_month, color: Colors.white),
                ],
              ),
            ),
          ),

          // Perforation
          Container(
            color: Colors.white,
            child: Row(
              children: [
                const SizedBox(width: 10, height: 20, child: DecoratedBox(decoration: BoxDecoration(color: kEventSurface, borderRadius: BorderRadius.horizontal(right: Radius.circular(10))))),
                Expanded(child: LayoutBuilder(builder: (context, constraints) {
                  return Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: List.generate((constraints.constrainWidth() / 10).floor(), (_) => const SizedBox(width: 5, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey)))),
                  );
                })),
                const SizedBox(width: 10, height: 20, child: DecoratedBox(decoration: BoxDecoration(color: kEventSurface, borderRadius: BorderRadius.horizontal(left: Radius.circular(10))))),
              ],
            ),
          ),

          // Tickets
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              children: _ticketTypes.map((ticket) {
                final code = ticket['code'] as String;
                final count = _ticketCounts[code] ?? 0;
                final price = ticket['price'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ticket['name'] ?? 'Ticket', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text("\$$price", style: const TextStyle(color: kEventPink, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            _qtyBtn(Icons.remove, count > 0 ? () => setState(() => _ticketCounts[code] = count - 1) : null),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            _qtyBtn(Icons.add, () => setState(() => _ticketCounts[code] = count + 1)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 18, color: onTap != null ? Colors.black : Colors.grey)),
    );
  }

  Widget _buildSpecs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _specCard(Icons.confirmation_number_outlined, "Instant", "Booking"),
          const SizedBox(width: 12),
          _specCard(Icons.supervised_user_circle_outlined, "Guide", "Included"),
          const SizedBox(width: 12),
          _specCard(Icons.language, "Language", "English"),
        ],
      ),
    );
  }

  Widget _specCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: kEventPurple, size: 24),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("About Event", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kEventDark)),
          const SizedBox(height: 8),
          HtmlWidget(
            _eventData!['content'] ?? '',
            textStyle: TextStyle(color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQs() {
    final faqs = _eventData!['faqs'];
    if (faqs is! List || faqs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("FAQs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kEventDark)),
          const SizedBox(height: 10),
          ...faqs.map((f) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: Text(f['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                HtmlWidget(f['content'] ?? '', textStyle: TextStyle(color: Colors.grey[700])),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    final reviews = _eventData!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kEventDark)),
        ),
        SizedBox(
          height: 180, 
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final r = reviews[i];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: kEventPurple.withOpacity(0.1),
                          child: const Icon(Icons.person, size: 18, color: kEventPurple),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r['author']?['name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Row(children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${r['rate_number']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(r['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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

  Widget _buildRelatedEvents() {
    final related = _eventData!['related'];
    if (related is! List || related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("You Might Like", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kEventDark)),
        ),
        SizedBox(
          height: 250, 
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = related[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: item['id']))),
                child: Container(
                  width: 180,
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
                          child: Image.network(
                            item['image'] ?? '', 
                            width: double.infinity, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
                          ),
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
                              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("\$${item['price']}", style: const TextStyle(color: kEventPink, fontWeight: FontWeight.bold, fontSize: 15)),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Price", style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text("\$${_calculateTotal().toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kEventDark)),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting ? null : _bookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: kEventPurple,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: kEventPurple.withOpacity(0.4),
              ),
              child: _submitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("Book Ticket", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. EVENT CHECKOUT SCREEN (INCLUDED)
// =============================================================================

class EventCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String eventTitle;
  final DateTime date;
  final double total;

  const EventCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.eventTitle,
    required this.date,
    required this.total,
  }) : super(key: key);

  @override
  State<EventCheckoutScreen> createState() => _EventCheckoutScreenState();
}

class _EventCheckoutScreenState extends State<EventCheckoutScreen> {
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

      // 1. Checkout Preview
      try {
        await http.get(Uri.parse('https://megatour.vn/api/booking/${widget.bookingCode}/checkout'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
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
        Uri.parse('https://megatour.vn/api/booking/doCheckout'),
        headers: headers,
        body: checkoutBody,
      );

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
        title: const Column(children: [Icon(Icons.check_circle, color: kEventPurple, size: 64), SizedBox(height: 16), Text('Booking Confirmed!')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your tickets are booked successfully.'),
            const SizedBox(height: 16),
            SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kEventPurple)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Back to Home')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kEventSurface,
      appBar: AppBar(title: const Text('Checkout', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total Amount", style: TextStyle(color: Colors.grey[600])), Text('\$${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: kEventPink, fontSize: 18))]),
                    const Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MMM dd').format(widget.date)), const Text('Event Ticket', style: TextStyle(fontWeight: FontWeight.bold))]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Guest Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _input(_firstName, 'First Name', Icons.person),
              _input(_lastName, 'Last Name', Icons.person),
              _input(_email, 'Email', Icons.email, type: TextInputType.emailAddress),
              _input(_phone, 'Phone', Icons.phone, type: TextInputType.phone),
              _input(_address, 'Address', Icons.home),
              _input(_country, 'Country', Icons.flag),
              _input(_notes, 'Notes (Optional)', Icons.note, req: false),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCheckout,
                  style: ElevatedButton.styleFrom(backgroundColor: kEventPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm & Pay', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c, keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: Colors.white),
        validator: (v) => req && (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }
}