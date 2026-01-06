import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

// =============================================================================
// 1. THEME CONSTANTS (Vibrant Sunset Style)
// =============================================================================
const Color kTourPrimary = Color(0xFFFF512F);
const Color kTourGradient1 = Color(0xFFFF512F);
const Color kTourGradient2 = Color(0xFFDD2476);
const Color kTourText = Color(0xFF1F2937);
const Color kTourSurface = Color(0xFFF9FAFB);

// =============================================================================
// 2. TOUR DETAIL SCREEN
// =============================================================================
class TourDetailScreen extends StatefulWidget {
  final int tourId;

  const TourDetailScreen({
    Key? key,
    required this.tourId,
  }) : super(key: key);

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  // Booking State
  DateTime? _selectedDate;
  List<dynamic> _personTypes = [];
  final Map<String, int> _personCounts = {}; 
  int _simpleGuestCount = 1;

  // UI State
  final PageController _pageController = PageController();
  Timer? _galleryTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadTour();
  }

  @override
  void dispose() {
    _galleryTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadTour() async {
    try {
      final res = await http.get(
        Uri.parse('https://megatour.vn/api/tour/detail/${widget.tourId}'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _data = json['data'];
            _loading = false;
            
            if (_data!['person_types'] != null && (_data!['person_types'] as List).isNotEmpty) {
              _personTypes = List.from(_data!['person_types']);
              _personCounts.clear(); 
              for (var type in _personTypes) {
                String? code = type['code'];
                if (code == null && type['name'] != null) code = type['name'];
                
                if (code != null) {
                  _personCounts[code] = (code == 'adult' || _personTypes.indexOf(type) == 0) ? 1 : 0;
                }
              }
            } else {
              _personTypes = [];
              _simpleGuestCount = 1;
            }
          });
          _startAutoSlide();
        }
      } else {
        throw Exception('Failed to load tour');
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading tour: $e');
    }
  }

  void _startAutoSlide() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.length < 2) return;

    _galleryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _currentPage = (_currentPage + 1) % gallery.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PRICE CALCULATION
  // ---------------------------------------------------------------------------
  double _calculateTotal() {
    double total = 0.0;
    
    if (_personTypes.isNotEmpty) {
      for (var type in _personTypes) {
        String? code = type['code'] ?? type['name'];
        if (code == null) continue;

        int count = _personCounts[code] ?? 0;
        String priceRaw = '${type['price']}';
        String priceClean = priceRaw.replaceAll(',', ''); 
        double price = double.tryParse(priceClean) ?? 0.0;
        
        total += price * count;
      }
    } else if (_data != null) {
       String priceRaw = '${_data!['sale_price'] ?? _data!['price']}';
       String priceClean = priceRaw.replaceAll(',', '');
       double price = double.tryParse(priceClean) ?? 0.0;
       total = price * _simpleGuestCount; 
    }
    
    return total;
  }

  // ---------------------------------------------------------------------------
  // BOOKING LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _bookNow() async {
    if (_selectedDate == null) return _snack('Please select a departure date', Colors.orange);
    
    int totalPeople = 0;
    if (_personTypes.isNotEmpty) {
      totalPeople = _personCounts.values.fold(0, (sum, count) => sum + count);
    } else {
      totalPeople = _simpleGuestCount;
    }

    if (totalPeople < 1) return _snack('Please select at least 1 person', Colors.orange);

    final auth = context.read<AuthProvider>();
    String? token = auth.token;
    if (token == null) {
       final prefs = await SharedPreferences.getInstance();
       token = prefs.getString('access_token');
    }
    if (token == null) return _snack('Please login to book', Colors.red);

    setState(() => _submitting = true);

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      final Map<String, dynamic> payload = {
        'service_id': widget.tourId,
        'service_type': 'tour',
        'start_date': startStr,
        'adults': totalPeople, 
      };

      if (_personTypes.isNotEmpty) {
        List<Map<String, dynamic>> selectedPersonTypes = [];
        for (var type in _personTypes) {
          String? code = type['code'] ?? type['name'];
          if (code == null) continue;

          int count = _personCounts[code] ?? 0;
          if (count > 0) {
            String priceStr = '${type['price']}'.replaceAll(',', '');
            selectedPersonTypes.add({
              'code': code,
              'number': count,
              'price': priceStr,
              'name': type['name'] ?? '',
            });
          }
        }
        payload['person_types'] = selectedPersonTypes;
      }

      final res = await http.post(
        Uri.parse('https://megatour.vn/api/booking/addToCart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json', 
        },
        body: jsonEncode(payload),
      );

      final json = jsonDecode(res.body);

      if (res.statusCode == 200 && (json['status'] == 1 || json['status'] == true)) {
        String? code = json['booking_code'] ?? json['data']?['code'] ?? json['code'];
        
        if (code != null && mounted) {
           Navigator.push(
             context, 
             MaterialPageRoute(
               builder: (_) => TourCheckoutScreen(
                 bookingCode: code!,
                 tourTitle: _data?['title'] ?? 'Tour Booking',
                 date: _selectedDate!,
                 guestSummary: '$totalPeople Guests',
                 total: _calculateTotal(),
               ),
             ),
           );
        } else {
           throw Exception('No booking code returned');
        }
      } else {
        String msg = json['message'] ?? 'Booking failed';
        if (json['errors'] != null) {
           msg = json['errors'].toString();
        }
        throw Exception(msg);
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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return const Scaffold(body: Center(child: Text('Tour not found')));

    return Scaffold(
      backgroundColor: kTourSurface,
      body: Stack(
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
                      _buildBookingCard(),
                      const SizedBox(height: 32),
                      _buildOverview(),
                      const SizedBox(height: 24),
                      _buildIncludedExcluded(), // New Section
                      const SizedBox(height: 24),
                      _buildItinerary(), // Slide-able
                      const SizedBox(height: 24),
                      _buildFAQs(),
                      const SizedBox(height: 24),
                      _buildReviews(),
                      const SizedBox(height: 24),
                      _buildRelated(),
                      const SizedBox(height: 120),
                    ],
                  ),
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

  SliverAppBar _buildSliverAppBar() {
    final gallery = _data!['gallery'] as List? ?? [];
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: IconButton(
            icon: Icon(_data!['is_wishlist'] == 1 ? Icons.favorite : Icons.favorite_border, color: kTourPrimary),
            onPressed: () {}, 
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: gallery.isNotEmpty 
            ? PageView.builder(
                controller: _pageController,
                itemCount: gallery.length,
                itemBuilder: (_, i) => Image.network(gallery[i], fit: BoxFit.cover),
              )
            : Image.network(_data!['image'] ?? '', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildHeader() {
    final review = _data!['review_score'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          _data!['title'] ?? '',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kTourText, height: 1.2),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on, color: kTourPrimary, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _data!['location']?['name'] ?? '',
                style: const TextStyle(color: kTourText, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (review != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${review['score_total']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            _metaBadge(Icons.schedule, _data!['duration'] ?? 'N/A'),
            _metaBadge(Icons.group, "Max ${_data!['max_people'] ?? 'N/A'}"),
          ],
        ),
      ],
    );
  }

  Widget _metaBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBookingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kTourGradient1, kTourGradient2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kTourGradient1.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BOOK YOUR TRIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context, 
                firstDate: DateTime.now(), 
                lastDate: DateTime.now().add(const Duration(days: 365)), 
                initialDate: _selectedDate ?? DateTime.now()
              );
              if (d != null) setState(() => _selectedDate = d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _selectedDate == null ? "Select Departure Date" : DateFormat('EEE, dd MMM yyyy').format(_selectedDate!),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (_personTypes.isNotEmpty) 
            ..._personTypes.map((type) {
              String? code = type['code'] ?? type['name'];
              if (code == null) return const SizedBox.shrink();

              return _PersonTypeRow(
                type: type,
                count: _personCounts[code] ?? 0,
                onChanged: (val) => setState(() => _personCounts[code] = val),
              );
            }).toList()
          else
            _buildSimpleGuestCounter(),
        ],
      ),
    );
  }

  Widget _buildSimpleGuestCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Guests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Per person", style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              _qtyBtn(Icons.remove, _simpleGuestCount > 1 ? () => setState(() => _simpleGuestCount--) : null),
              SizedBox(width: 30, child: Center(child: Text('$_simpleGuestCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)))),
              _qtyBtn(Icons.add, () => setState(() => _simpleGuestCount++)),
            ],
          ),
        )
      ],
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 18, color: onTap != null ? Colors.black : Colors.grey)),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Overview"),
        const SizedBox(height: 12),
        HtmlWidget(
          _data!['content'] ?? '',
          textStyle: const TextStyle(color: Colors.grey, height: 1.6, fontSize: 15),
        ),
      ],
    );
  }

  // --- NEW: INCLUDED / EXCLUDED SECTION ---
  Widget _buildIncludedExcluded() {
    final include = _data!['include'] as List? ?? [];
    final exclude = _data!['exclude'] as List? ?? [];

    if (include.isEmpty && exclude.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("What's Included"),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (include.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: include.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item['title'] ?? '', style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            if (include.isNotEmpty && exclude.isNotEmpty) const SizedBox(width: 16),
            if (exclude.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: exclude.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.close, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item['title'] ?? '', style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- UPDATED: SLIDE-ABLE ITINERARY ---
  Widget _buildItinerary() {
    final list = _data!['itinerary'];
    if (list is! List || list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Itinerary"),
        const SizedBox(height: 16),
        SizedBox(
          height: 320, // Height for image + content
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = list[i];
              String? imgUrl = item['image'];
              
              return Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Image
                    if (imgUrl != null && imgUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(imgUrl, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(height: 140, color: Colors.grey[200])),
                      ),
                    
                    // Day Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: kTourPrimary, borderRadius: BorderRadius.circular(8)),
                                  child: Text("Day ${i + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item['desc'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: HtmlWidget(item['content'] ?? '', textStyle: const TextStyle(fontSize: 13, color: kTourText, height: 1.4)),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildFAQs() {
    final faqs = _data!['faqs'];
    if (faqs is! List || faqs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("FAQs"),
        const SizedBox(height: 12),
        ...faqs.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12), color: Colors.white),
          child: ExpansionTile(
            title: Text(f['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            childrenPadding: const EdgeInsets.all(16),
            children: [HtmlWidget(f['content'] ?? '', textStyle: const TextStyle(color: Colors.grey))],
          ),
        )),
      ],
    );
  }

  Widget _buildReviews() {
    final reviews = _data!['review_lists']?['data'];
    if (reviews is! List || reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Reviews (${reviews.length})"),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final r = reviews[i];
              return Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(backgroundColor: kTourPrimary.withOpacity(0.1), child: const Icon(Icons.person, color: kTourPrimary)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r['author']?['name'] ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Row(children: [const Icon(Icons.star, size: 14, color: Colors.amber), Text('${r['rate_number']}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(r['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Expanded(child: Text(r['content'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, height: 1.4))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelated() {
    final related = _data!['related'];
    if (related is! List || related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Similar Tours"),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: related.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final item = related[i];
              String? img = item['image'];
              
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TourDetailScreen(tourId: item['id']))),
                child: Container(
                  width: 200,
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
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: img != null 
                            ? Image.network(img, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[200]))
                            : Container(color: Colors.grey[200]),
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
                              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("\$${item['price']}", style: const TextStyle(fontWeight: FontWeight.bold, color: kTourPrimary, fontSize: 16)),
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
        // Remove padding here so the background color extends to the very bottom edge
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,-5))],
        ),
        child: SafeArea(
          top: false, // Only respect bottom safe area (home indicator)
          child: Padding(
            // Reduced vertical padding from 20 to 12
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "\$${_calculateTotal().toStringAsFixed(0)}", 
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTourText)
                    ),
                    const Text("Total Price", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submitting ? null : _bookNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kTourPrimary,
                    foregroundColor: Colors.white,
                    // Reduced internal button padding
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _submitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Book Now", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTourText));
}

// =============================================================================
// 3. ISOLATED TICKET ROW
// =============================================================================
class _PersonTypeRow extends StatelessWidget {
  final Map<String, dynamic> type;
  final int count;
  final ValueChanged<int> onChanged;

  const _PersonTypeRow({
    Key? key,
    required this.type,
    required this.count,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type['name'] ?? 'Ticket', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text("\$${type['price'] ?? 0}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                _qtyBtn(Icons.remove, count > 0 ? () => onChanged(count - 1) : null),
                SizedBox(width: 24, child: Center(child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)))),
                _qtyBtn(Icons.add, () => onChanged(count + 1)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 16, color: onTap != null ? Colors.black : Colors.grey)),
    );
  }
}

// =============================================================================
// 4. CHECKOUT SCREEN
// =============================================================================
class TourCheckoutScreen extends StatefulWidget {
  final String bookingCode;
  final String tourTitle;
  final DateTime date;
  final String guestSummary;
  final double total;

  const TourCheckoutScreen({
    Key? key,
    required this.bookingCode,
    required this.tourTitle,
    required this.date,
    required this.guestSummary,
    required this.total,
  }) : super(key: key);

  @override
  State<TourCheckoutScreen> createState() => _TourCheckoutScreenState();
}

class _TourCheckoutScreenState extends State<TourCheckoutScreen> {
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
      final auth = context.read<AuthProvider>();
      String? token = auth.token;
      if (token == null) {
         final prefs = await SharedPreferences.getInstance();
         token = prefs.getString('access_token');
      }
      
      if (token == null) throw Exception('Authentication required');

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      try {
        await http.get(Uri.parse('https://megatour.vn/api/booking/${widget.bookingCode}/checkout'), headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'});
      } catch (e) {
        debugPrint('Preview skipped: $e');
      }

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
        body: jsonEncode(checkoutBody),
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
        title: const Column(children: [Icon(Icons.check_circle, color: kTourPrimary, size: 64), SizedBox(height: 16), Text('Booking Confirmed!')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your tour has been successfully booked.'),
            const SizedBox(height: 16),
            SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTourText)),
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Confirm Booking', style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total Amount", style: TextStyle(color: Colors.grey[600])), Text('\$${widget.total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: kTourPrimary, fontSize: 18))]),
                    const Divider(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('MMM dd, yyyy').format(widget.date)), Text(widget.guestSummary, style: const TextStyle(fontWeight: FontWeight.bold))]),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Guest Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _input(_firstName, 'First Name', Icons.person_outline),
              _input(_lastName, 'Last Name', Icons.person_outline),
              _input(_email, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
              _input(_phone, 'Phone', Icons.phone_outlined, type: TextInputType.phone),
              _input(_address, 'Address', Icons.home_outlined),
              _input(_country, 'Country', Icons.flag_outlined),
              _input(_notes, 'Special Requests (Optional)', Icons.chat_bubble_outline, req: false),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleCheckout,
                  style: ElevatedButton.styleFrom(backgroundColor: kTourPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
        validator: (v) => req && (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }
}