import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../providers/search_provider.dart';
import '../../models/service_models.dart';
import '../services/tour_detail_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';

class TourListScreen extends StatefulWidget {
  final String title;

  TourListScreen({
    Key? key,
    this.title = 'Tours',
  }) : super(key: key);

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _locationController = TextEditingController();

  String _selectedSort = 'price_low_high';
  String? _selectedLocation;

  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _loadTours();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // API
  // --------------------------------------------------

  Future<void> _fetchLocations() async {
    final res =
        await http.get(Uri.parse('${ApiConfig.baseUrl}locations'));

    final json = jsonDecode(res.body);
    if (json['status'] == 1) {
      setState(() {
        _locations = (json['data'] as List)
            .map((e) => e['title'].toString())
            .toList();
      });
    }
  }

  void _loadTours() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().searchServices(
            serviceType: 'tour',
            orderBy: _selectedSort,
          );
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchProvider>().loadMore();
    }
  }

  // --------------------------------------------------
  // FILTER
  // --------------------------------------------------

  List<ServiceModel> _filterByLocation(List<ServiceModel> services) {
    if (_selectedLocation == null) return services;

    final q = _selectedLocation!.toLowerCase();
    return services.where((s) {
      final addr = s.address?.toLowerCase() ?? '';
      return addr.contains(q);
    }).toList();
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();
    final filtered = _filterByLocation(provider.services);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showSortSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --------------------------------------------------
          // LOCATION SEARCH (AUTOCOMPLETE)
          // --------------------------------------------------
          Padding(
            padding: EdgeInsets.all(16),
            child: Autocomplete<String>(
              optionsBuilder: (value) {
                if (value.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return _locations.where(
                  (l) =>
                      l.toLowerCase().contains(value.text.toLowerCase()),
                );
              },
              onSelected: (value) {
                setState(() {
                  _selectedLocation = value;
                  _locationController.text = value;
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onSubmit) {
                _locationController.text = controller.text;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchTours,
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (v) {
                    if (v.isEmpty) {
                      setState(() => _selectedLocation = null);
                    }
                  },
                );
              },
            ),
          ),

          // --------------------------------------------------
          // SORT
          // --------------------------------------------------
          SizedBox(
            height: 46,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _sortChip('Price ↑', 'price_low_high'),
                _sortChip('Price ↓', 'price_high_low'),
                _sortChip('Rating', 'rate_high_low'),
              ],
            ),
          ),

          Divider(height: 1),

          // --------------------------------------------------
          // LIST
          // --------------------------------------------------
          Expanded(
            child: provider.isLoading && filtered.isEmpty
                ? Center(child: CircularProgressIndicator())
                : provider.errorMessage != null
                    ? _error(provider.errorMessage!)
                    : filtered.isEmpty
                        ? _empty()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) =>
                                _tourCard(filtered[i]),
                          ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // CARD (UNCHANGED)
  // --------------------------------------------------

  Widget _tourCard(ServiceModel tour) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TourDetailScreen(tourId: tour.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.network(
                tour.image ?? '',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    tour.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // LOCATION ✅
                  if (tour.address != null)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tour.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 10),

                  // RATING + PRICE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (tour.reviewScore != null)
                        Row(
                          children: [
                            Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              tour.reviewScore!,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (tour.reviewCount != null)
                              Text(
                                ' (${tour.reviewCount})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (tour.salePrice != null)
                            Text(
                              '\$${tour.price}',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          Text(
                            '\$${tour.salePrice ?? tour.price}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
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

  // --------------------------------------------------

  Widget _sortChip(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _selectedSort == value,
        onSelected: (_) {
          setState(() => _selectedSort = value);
          _loadTours();
        },
      ),
    );
  }

  Widget _error(String msg) => Center(child: Text(msg));
  Widget _empty() => Center(child: Text(context.l10n.noToursFound));

  void _showSortSheet(BuildContext context) {}
}
