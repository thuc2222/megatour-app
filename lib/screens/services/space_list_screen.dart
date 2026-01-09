// lib/screens/services/space_list_screen.dart
// Modern Airbnb-style space listing with ambient gradients

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'space_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

class SpaceListScreen extends StatefulWidget {
  SpaceListScreen({Key? key}) : super(key: key);

  @override
  State<SpaceListScreen> createState() => _SpaceListScreenState();
}

class _SpaceListScreenState extends State<SpaceListScreen> {
  bool isLoading = false;
  List<dynamic> spaces = [];
  String? errorMessage;
  
  String? searchQuery;
  String? locationFilter;
  RangeValues priceRange = RangeValues(50, 1000);
  int guests = 1;

  @override
  void initState() {
    super.initState();
    _fetchSpaces();
  }

  Future<void> _fetchSpaces() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final queryParams = <String, String>{};
      
      if (searchQuery != null && searchQuery!.isNotEmpty) {
        queryParams['service_name'] = searchQuery!;
      }
      
      if (locationFilter != null && locationFilter!.isNotEmpty) {
        queryParams['location_name'] = locationFilter!;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}space/search').replace(
  queryParameters: queryParams,
);
      
      debugPrint('🏠 Fetching spaces: $uri');
      
      final res = await http.get(uri);

      debugPrint('📥 Response: ${res.statusCode}');

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        
        List<dynamic> spacesList = [];
        
        if (body is Map) {
          if (body['data'] is Map && body['data']['data'] is List) {
            spacesList = body['data']['data'];
          } else if (body['data'] is List) {
            spacesList = body['data'];
          }
        } else if (body is List) {
          spacesList = body;
        }

        debugPrint('✅ Loaded ${spacesList.length} spaces');

        setState(() {
          spaces = spacesList;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error: ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() {
        errorMessage = e.toString();
        spaces = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSearchBar()),
          _buildSpaceList(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B9D).withOpacity(0.1),
                Color(0xFFC06FFE).withOpacity(0.1),
              ],
            ),
          ),
        ),
        title: Text(
          context.l10n.uniqueSpaces,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.tune, color: Colors.black),
          onPressed: _showFilters,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.searchSpaces,
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onChanged: (v) => searchQuery = v,
              onSubmitted: (_) => _fetchSpaces(),
            ),
          ),
          
          SizedBox(height: 12),
          
          // Quick Filters
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                _filterChip('Apartments', 'apartment'),
                _filterChip('Houses', 'house'),
                _filterChip('Villas', 'villa'),
                _filterChip('Studios', 'studio'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = locationFilter == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => locationFilter = value);
          _fetchSpaces();
        },
        selectedColor: Colors.black,
        backgroundColor: Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SPACE LIST
  // ---------------------------------------------------------------------------

  Widget _buildSpaceList() {
    if (isLoading) {
      return SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(errorMessage!),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchSpaces,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (spaces.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_work_outlined, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                context.l10n.noSpacesFound,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _spaceCard(spaces[index]),
          childCount: spaces.length,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SPACE CARD (AIRBNB STYLE)
  // ---------------------------------------------------------------------------

  Widget _spaceCard(dynamic space) {
    final int spaceId = int.tryParse(space['id'].toString()) ?? 0;
    final String title = space['title'] ?? 'Untitled Space';
    final String? imageUrl = space['image'];
    final String? locationName = space['location']?['name'];
    final String? price = space['price']?.toString();
    final String? salePrice = space['sale_price']?.toString();
    final dynamic reviewScore = space['review_score'];
    final int? bedrooms = int.tryParse(space['number_of_rooms']?.toString() ?? '0');
    final int? bathrooms = int.tryParse(space['number_of_bathrooms']?.toString() ?? '0');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpaceDetailScreen(spaceId: spaceId),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE WITH GRADIENT OVERLAY
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
                
                // Ambient Gradient Overlay
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
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
                  ),
                ),
                
                // Sale Badge
                if (salePrice != null && salePrice != '0')
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        context.l10n.specialOffer,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Favorite Button
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 20,
                      color: Colors.black,
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
                  // Location & Rating
                  Row(
                    children: [
                      if (locationName != null)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationName,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (reviewScore != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.star,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                reviewScore['score_total']?.toString() ?? '0',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),

                  SizedBox(height: 12),

                  // Amenities
                  Row(
                    children: [
                      if (bedrooms != null && bedrooms > 0)
                        _amenityChip(Icons.bed, '$bedrooms bed${bedrooms > 1 ? 's' : ''}'),
                      if (bedrooms != null && bathrooms != null)
                        SizedBox(width: 8),
                      if (bathrooms != null && bathrooms > 0)
                        _amenityChip(Icons.bathtub, '$bathrooms bath${bathrooms > 1 ? 's' : ''}'),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (salePrice != null && salePrice != '0')
                            Text(
                              '\$$price',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                                ).createShader(bounds),
                                child: Text(
                                  '\$${salePrice != null && salePrice != '0' ? salePrice : price}',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  context.l10n.night,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFC06FFE)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SpaceDetailScreen(spaceId: spaceId),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              child: Text(
                                context.l10n.view,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[300]!, Colors.grey[200]!],
        ),
      ),
      child: Icon(Icons.home_work, size: 64, color: Colors.grey),
    );
  }

  Widget _amenityChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            
            Text(context.l10n.priceRange),
            RangeSlider(
              min: 50,
              max: 1000,
              values: priceRange,
              onChanged: (v) => setState(() => priceRange = v),
            ),
            Text('\$${priceRange.start.round()} - \$${priceRange.end.round()}'),
            
            SizedBox(height: 24),
            
            Text(context.l10n.guests1),
            Row(
              children: [
                IconButton(
                  onPressed: guests > 1 ? () => setState(() => guests--) : null,
                  icon: Icon(Icons.remove_circle_outline),
                ),
                Text('$guests'),
                IconButton(
                  onPressed: () => setState(() => guests++),
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _fetchSpaces();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(context.l10n.applyFilters),
              ),
            ),
          ],
        ),
      ),
    );
  }
}