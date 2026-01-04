// lib/screens/services/space_detail_screen.dart
// Modern Airbnb-style space detail with guest checkout

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../booking/space_checkout_screen.dart';

class SpaceDetailScreen extends StatefulWidget {
  final int spaceId;

  const SpaceDetailScreen({
    Key? key,
    required this.spaceId,
  }) : super(key: key);

  @override
  State<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends State<SpaceDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _guests = 2;

  @override
  void initState() {
    super.initState();
    _future = _fetchSpaceDetail();
  }

  Future<Map<String, dynamic>> _fetchSpaceDetail() async {
    final res = await http.get(
      Uri.parse('https://megatour.vn/api/space/detail/${widget.spaceId}'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load space');
    }

    final jsonData = json.decode(res.body);
    return jsonData['data'];
  }

  int _calculateNights() {
    if (_checkIn == null || _checkOut == null) return 0;
    return _checkOut!.difference(_checkIn!).inDays;
  }

  double _calculateTotal(String? price) {
    final nights = _calculateNights();
    if (nights == 0 || price == null) return 0;
    
    final pricePerNight = double.tryParse(price) ?? 0;
    return pricePerNight * nights;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Error loading space"));
          }

          final space = snapshot.data!;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildAppBar(space),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(space),
                        _buildBookingCard(space),
                        _buildAmenities(space),
                        _buildDescription(space),
                        _buildReviews(space),
                        const SizedBox(height: 100),
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
      bottomSheet: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return _buildBottomBar(snapshot.data!);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR (IMAGE GALLERY)
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar(Map<String, dynamic> space) {
    final gallery = space['gallery'] as List? ?? [];
    
    return SliverAppBar(
      expandedHeight: 400,
      automaticallyImplyLeading: false,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: gallery.isNotEmpty
            ? PageView.builder(
                itemCount: gallery.length,
                itemBuilder: (_, i) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        gallery[i],
                        fit: BoxFit.cover,
                      ),
                      // Ambient gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : Container(
                color: Colors.grey[300],
                child: const Icon(Icons.home_work, size: 80),
              ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(Map<String, dynamic> space) {
    final review = space['review_score'];
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            space['title'] ?? '',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (review != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${review['score_total']} • ${review['total_review']} reviews',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),
              if (space['location'] != null)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          space['location']['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKING CARD
  // ---------------------------------------------------------------------------

  Widget _buildBookingCard(Map<String, dynamic> space) {
    final price = space['sale_price'] ?? space['price'];
    final nights = _calculateNights();
    final total = _calculateTotal(price?.toString());
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B9D).withOpacity(0.1),
            const Color(0xFFC06FFE).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B9D).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Price
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                ).createShader(bounds),
                child: Text(
                  '\$$price',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Text(
                ' / night',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Date Selectors
          Row(
            children: [
              Expanded(
                child: _dateSelector(
                  'CHECK-IN',
                  _checkIn,
                  () => _selectDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dateSelector(
                  'CHECKOUT',
                  _checkOut,
                  () => _selectDate(false),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Guests
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'GUESTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _guests > 1
                          ? () => setState(() => _guests--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.black,
                    ),
                    Text(
                      '$_guests',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _guests++),
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.black,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (nights > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$$price x $nights nights'),
                      Text('\$${total.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                        ).createShader(bounds),
                        child: Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateSelector(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              date != null ? DateFormat('MMM dd').format(date) : 'Add date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: date != null ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isCheckIn) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: isCheckIn
          ? (_checkIn ?? DateTime.now())
          : (_checkOut ?? DateTime.now().add(const Duration(days: 1))),
    );
    
    if (date != null) {
      setState(() {
        if (isCheckIn) {
          _checkIn = date;
          if (_checkOut != null && _checkOut!.isBefore(date)) {
            _checkOut = date.add(const Duration(days: 1));
          }
        } else {
          _checkOut = date;
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // AMENITIES
  // ---------------------------------------------------------------------------

  Widget _buildAmenities(Map<String, dynamic> space) {
    final bedrooms = space['number_of_rooms'];
    final bathrooms = space['number_of_bathrooms'];
    final beds = space['number_of_beds'];
    final maxGuests = space['max_guests'];
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What this place offers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (bedrooms != null)
                _amenityCard(Icons.bed, '$bedrooms Bedrooms'),
              if (bathrooms != null)
                _amenityCard(Icons.bathtub, '$bathrooms Bathrooms'),
              if (beds != null)
                _amenityCard(Icons.king_bed, '$beds Beds'),
              if (maxGuests != null)
                _amenityCard(Icons.people, 'Up to $maxGuests guests'),
              _amenityCard(Icons.wifi, 'WiFi'),
              _amenityCard(Icons.kitchen, 'Kitchen'),
              _amenityCard(Icons.local_parking, 'Free parking'),
              _amenityCard(Icons.pool, 'Pool'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amenityCard(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESCRIPTION
  // ---------------------------------------------------------------------------

  Widget _buildDescription(Map<String, dynamic> space) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this space',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          HtmlWidget(space['content'] ?? 'No description available.'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REVIEWS
  // ---------------------------------------------------------------------------

  Widget _buildReviews(Map<String, dynamic> space) {
    final reviews = space['review_lists']?['data'] as List? ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...reviews.take(3).map((r) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text(r['author']?['name']?.substring(0, 1) ?? 'U'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['author']?['name'] ?? 'Guest',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Icon(
                                    i < (int.tryParse(r['rate_number'].toString()) ?? 0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(r['content'] ?? ''),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOTTOM BAR
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar(Map<String, dynamic> space) {
    final canBook = _checkIn != null && _checkOut != null && _calculateNights() > 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Container(
            decoration: BoxDecoration(
              gradient: canBook
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                    )
                  : null,
              color: canBook ? null : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: canBook ? () => _proceedToCheckout(space) : null,
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: Text(
                    canBook ? 'Reserve' : 'Select dates to reserve',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _proceedToCheckout(Map<String, dynamic> space) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpaceCheckoutScreen(
          spaceId: widget.spaceId,
          spaceTitle: space['title'] ?? 'Space',
          checkIn: _checkIn!,
          checkOut: _checkOut!,
          guests: _guests,
          pricePerNight: double.tryParse(
            (space['sale_price'] ?? space['price']).toString(),
          ) ?? 0,
        ),
      ),
    );
  }
}