// lib/screens/services/boat_list_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'boat_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';

class BoatListScreen extends StatefulWidget {
  BoatListScreen({Key? key}) : super(key: key);

  @override
  State<BoatListScreen> createState() => _BoatListScreenState();
}

class _BoatListScreenState extends State<BoatListScreen> {
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _boats = [];
  Map<String, dynamic>? _filters;
  
  bool _loading = true;
  String _selectedSort = 'price_low_high';
  String? _searchQuery;
  String? _selectedLocation;
  
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _loadBoats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreBoats();
    }
  }

  // ---------------------------------------------------------------------------
  // API CALLS
  // ---------------------------------------------------------------------------

  Future<void> _loadFilters() async {
    try {
      final res = await http.get(
        Uri.parse('https://megatour.vn/api/boat/filters'),
      );
      if (res.statusCode == 200) {
        setState(() => _filters = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  Future<void> _loadBoats({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || _currentPage >= _totalPages) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _currentPage = 1;
      });
    }

    try {
      final queryParams = <String, String>{
        'page': (loadMore ? _currentPage + 1 : 1).toString(),
        'limit': '12',
      };

      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        queryParams['service_name'] = _searchQuery!;
      }

      if (_selectedLocation != null) {
        queryParams['location_name'] = _selectedLocation!;
      }

      if (_selectedSort.isNotEmpty) {
        queryParams['orderby'] = _selectedSort;
      }

      final uri = Uri.https(
        'megatour.vn',
        '/api/boat/search',
        queryParams,
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List newBoats = data['data'] ?? [];

        setState(() {
          if (loadMore) {
            _boats.addAll(newBoats);
            _currentPage++;
          } else {
            _boats = newBoats;
            _currentPage = data['current_page'] ?? 1;
          }
          _totalPages = data['last_page'] ?? 1;
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _loadMoreBoats() {
    _loadBoats(loadMore: true);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A237E).withOpacity(0.05),
              Color(0xFF0D47A1).withOpacity(0.02),
            ],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(),
            _buildSearchBar(),
            _buildSortChips(),
            _buildBoatGrid(),
            if (_loadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
                Color(0xFF01579B),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Wave pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: WavePainter(),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.directions_boat,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.cruiseBoats,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  context.l10n.sailIntoYourDreamVacation,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  SliverToBoxAdapter _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF1565C0).withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: context.l10n.searchBoatsCruises,
              prefixIcon: Icon(
                Icons.search,
                color: Colors.blue.shade700,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  Icons.tune,
                  color: Colors.blue.shade700,
                ),
                onPressed: () => _showFilters(),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onChanged: (v) => _searchQuery = v.isEmpty ? null : v,
            onSubmitted: (_) => _loadBoats(),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SORT CHIPS
  // ---------------------------------------------------------------------------

  SliverToBoxAdapter _buildSortChips() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          children: [
            _sortChip('Price Low → High', 'price_low_high', Icons.arrow_upward),
            _sortChip('Price High → Low', 'price_high_low', Icons.arrow_downward),
            _sortChip('Top Rated', 'rate_high_low', Icons.star),
            _sortChip('Featured', 'featured', Icons.favorite),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value, IconData icon) {
    final selected = _selectedSort == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.blue.shade700,
            ),
            SizedBox(width: 6),
            Text(label),
          ],
        ),
        onSelected: (_) {
          setState(() => _selectedSort = value);
          _loadBoats();
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.shade700,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.blue.shade700,
          fontWeight: FontWeight.w600,
        ),
        elevation: selected ? 4 : 0,
        shadowColor: Colors.blue.shade200,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOAT GRID
  // ---------------------------------------------------------------------------

  SliverPadding _buildBoatGrid() {
    if (_loading) {
      return SliverPadding(
        padding: EdgeInsets.zero,
        sliver: SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_boats.isEmpty) {
      return SliverPadding(
        padding: EdgeInsets.all(40),
        sliver: SliverToBoxAdapter(
          child: Column(
            children: [
              Icon(
                Icons.sailing,
                size: 80,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 16),
              Text(
                context.l10n.noBoatsFound,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.45,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBoatCard(_boats[index]),
          childCount: _boats.length,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOAT CARD
  // ---------------------------------------------------------------------------

  Widget _buildBoatCard(dynamic boat) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BoatDetailScreen(
              boatId: boat['id'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100.withOpacity(0.5),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade200,
                          Colors.blue.shade400,
                        ],
                      ),
                    ),
                    child: boat['image'] != null
                        ? Image.network(
                            boat['image'],
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.directions_boat,
                            size: 48,
                            color: Colors.white,
                          ),
                  ),
                ),
                
                // Gradient overlay
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),

                // Featured badge
                if (boat['is_featured'] == 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.orange.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            context.l10n.featured,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // CONTENT
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boat['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                    
                    SizedBox(height: 6),

                    if (boat['location'] != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              boat['location']['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),

                    Spacer(),

                    // Rating
                    if (boat['review_score'] != null)
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 12,
                                  color: Colors.green.shade700,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  boat['review_score']['score_total']
                                      ?.toString() ??
                                      '0',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 8),

                    // Price
                    Row(
                      children: [
                        if (boat['sale_price'] != null) ...[
                          Text(
                            '\$${boat['price']}',
                            style: TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          SizedBox(width: 6),
                        ],
                        Text(
                          '\$${boat['sale_price'] ?? boat['price']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          context.l10n.day1,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTERS
  // ---------------------------------------------------------------------------

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    context.l10n.filters,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedLocation = null;
                      });
                      Navigator.pop(context);
                      _loadBoats();
                    },
                    child: Text(context.l10n.reset),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Text(
                    context.l10n.location,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Ha Long Bay',
                      'Nha Trang',
                      'Phu Quoc',
                      'Da Nang',
                    ].map((loc) {
                      final selected = _selectedLocation == loc;
                      return FilterChip(
                        selected: selected,
                        label: Text(loc),
                        onSelected: (_) {
                          setState(() {
                            _selectedLocation = selected ? null : loc;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadBoats();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(context.l10n.applyFilters),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WAVE PAINTER
// ---------------------------------------------------------------------------

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.6,
      size.width * 0.5,
      size.height * 0.7,
    );
    
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.8,
      size.width,
      size.height * 0.7,
    );
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}