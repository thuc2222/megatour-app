import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'car_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

class CarListScreen extends StatefulWidget {
  CarListScreen({Key? key}) : super(key: key);

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  bool isLoading = false;
  List<dynamic> cars = [];
  String? errorMessage;

  String? selectedType;
  RangeValues priceRange = RangeValues(50, 1000);

  // ================= AUTOCOMPLETE STATE =================
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  List<Map<String, dynamic>> _locations = [];
  String _searchText = '';
  int? _selectedLocationId;
  // ======================================================

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchCars();
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ---------------------------------------------------------------------------
  // API LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _fetchLocations() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}locations'));
      final body = jsonDecode(res.body);
      if (body['status'] == 1) {
        setState(() {
          _locations = (body['data'] as List).map((e) => {
            'id': e['id'],
            'title': e['title'].toString(),
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchCars() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final queryParams = <String, String>{};
      // Keep your original filter logic if needed
      if (selectedType != null) queryParams['type'] = selectedType!;

      final uri = Uri.parse('${ApiConfig.baseUrl}car/search').replace(
  queryParameters: queryParams,
);
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        List<dynamic> carsList = [];
        if (body is Map) {
          if (body['data'] is Map && body['data']['data'] is List) {
            carsList = body['data']['data'];
          } else if (body['data'] is List) {
            carsList = body['data'];
          }
        }
        setState(() {
          cars = carsList;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Error: ${res.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // CLIENT-SIDE FILTERING (For Search Logic)
  // ---------------------------------------------------------------------------

  List<dynamic> get _filteredCars {
    if (_searchText.isEmpty) return cars;

    // Filter by Location ID if something was picked from autocomplete
    if (_selectedLocationId != null) {
      return cars.where((car) {
        final carLocId = car['location_id'] ?? car['location']?['id'];
        return carLocId?.toString() == _selectedLocationId.toString();
      }).toList();
    }

    // Otherwise standard keyword search
    final q = _searchText.toLowerCase();
    return cars.where((car) {
      final loc = car['location']?['name']?.toString().toLowerCase() ?? '';
      final title = car['title']?.toString().toLowerCase() ?? '';
      return loc.contains(q) || title.contains(q);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // OVERLAY (Selectable Autocomplete)
  // ---------------------------------------------------------------------------

  void _showOverlay() {
    _removeOverlay();

    final suggestions = _locations
        .where((l) => l['title'].toLowerCase().contains(_searchText.toLowerCase()))
        .toList();

    if (suggestions.isEmpty || _searchText.isEmpty) return;

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final loc = suggestions[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined, color: Color(0xFF667eea)),
                    title: Text(loc['title']),
                    onTap: () {
                      setState(() {
                        _selectedLocationId = loc['id'];
                        _searchText = loc['title'];
                        _searchController.text = loc['title'];
                      });
                      _removeOverlay();
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) => _removeOverlay(),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildSearchBar()),
            _buildCarList(_filteredCars),
          ],
        ),
      ),
    );
  }

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
                const Color(0xFF667eea).withOpacity(0.15),
                const Color(0xFF764ba2).withOpacity(0.15),
              ],
            ),
          ),
        ),
        title: Text(
          context.l10n.carRentals,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune, color: Colors.black),
          onPressed: _showFilters,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.searchCars,
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (v) {
                  _searchText = v;
                  _selectedLocationId = null;
                  if (v.isEmpty) {
                    _removeOverlay();
                  } else {
                    _showOverlay();
                  }
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                _filterChip('Economy', 'economy'),
                _filterChip('SUV', 'suv'),
                _filterChip('Luxury', 'luxury'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = selectedType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => selectedType = value);
          _fetchCars();
        },
        selectedColor: const Color(0xFF667eea),
        backgroundColor: Colors.grey[200],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCarList(List<dynamic> list) {
    if (isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }
    if (errorMessage != null) {
      return SliverFillRemaining(child: Center(child: Text(errorMessage!)));
    }
    if (list.isEmpty) {
      return SliverFillRemaining(
        child: Center(child: Text(context.l10n.noCarsFound, style: const TextStyle(fontWeight: FontWeight.bold))),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _carCard(list[index]),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _carCard(dynamic car) {
    final int carId = int.tryParse(car['id'].toString()) ?? 0;
    final String title = car['title'] ?? 'Untitled Car';
    final String? imageUrl = car['image'];
    final String? locationName = car['location']?['name'];
    final String? price = car['price']?.toString();
    final String? salePrice = car['sale_price']?.toString();
    final dynamic reviewScore = car['review_score'];

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(carId: carId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: imageUrl != null
                      ? Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 200, color: Colors.grey[200]),
                ),
                if (salePrice != null && salePrice != '0')
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(context.l10n.deal, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (locationName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF667eea).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(Icons.location_on, size: 12, color: Color(0xFF667eea)),
                            const SizedBox(width: 4),
                            Text(locationName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF667eea))),
                          ]),
                        ),
                      const Spacer(),
                      if (reviewScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Row(children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(reviewScore['score_total']?.toString() ?? '0', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _specChip(Icons.settings, car['transmission_type'] ?? 'Auto'),
                      const SizedBox(width: 8),
                      _specChip(Icons.person, '${car['passenger'] ?? 4} seats'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (salePrice != null && salePrice != '0')
                            Text('\$$price', style: TextStyle(fontSize: 14, color: Colors.grey[600], decoration: TextDecoration.lineThrough)),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]).createShader(bounds),
                            child: Text('\$${salePrice != null && salePrice != '0' ? salePrice : price}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Text(context.l10n.rent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
      ]),
    );
  }

  void _showFilters() {}
}