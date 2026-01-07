import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  String _selectedSort = 'price_low_high';
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadTours();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadTours() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().searchServices(
            serviceType: 'tour',
            orderBy: _selectedSort,
            serviceName: _searchQuery,
          );
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();

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
          // SEARCH
          // --------------------------------------------------
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l10n.searchTours,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (v) => _searchQuery = v.isEmpty ? null : v,
              onSubmitted: (_) => _loadTours(),
            ),
          ),

          // --------------------------------------------------
          // SORT CHIPS
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
            child: provider.isLoading && provider.services.isEmpty
                ? Center(child: CircularProgressIndicator())
                : provider.errorMessage != null
                    ? _error(provider.errorMessage!)
                    : provider.services.isEmpty
                        ? _empty()
                        : RefreshIndicator(
                            onRefresh: () async => _loadTours(),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(16),
                              itemCount: provider.services.length +
                                  (provider.isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= provider.services.length) {
                                  return Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return _tourCard(provider.services[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // UI HELPERS
  // --------------------------------------------------

  Widget _sortChip(String label, String value) {
    final selected = _selectedSort == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedSort = value);
          _loadTours();
        },
      ),
    );
  }

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
            // --------------------------------------------------
            // IMAGE
            // --------------------------------------------------
            Stack(
              children: [
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Image.network(
                    tour.image ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Center(child: Icon(Icons.image, size: 48)),
                  ),
                ),
              ],
            ),

            // --------------------------------------------------
            // CONTENT
            // --------------------------------------------------
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tour.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),

                  if (tour.address != null)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 4),
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

                  SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Rating
                      if (tour.reviewScore != null)
                        Row(
                          children: [
                            Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            SizedBox(width: 4),
                            Text(
                              tour.reviewScore!,
                              style:
                                  TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (tour.reviewCount != null)
                              Text(
                                ' (${tour.reviewCount})',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600]),
                              ),
                          ],
                        ),

                      // Price
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

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _error(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 12),
          Text(msg),
          SizedBox(height: 12),
          ElevatedButton(onPressed: _loadTours, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tour, size: 64, color: Colors.grey[400]),
          SizedBox(height: 12),
          Text(
            context.l10n.noToursFound,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetItem('Price: Low to High', 'price_low_high'),
            _sheetItem('Price: High to Low', 'price_high_low'),
            _sheetItem('Rating', 'rate_high_low'),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(String label, String value) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        setState(() => _selectedSort = value);
        _loadTours();
      },
    );
  }
}
