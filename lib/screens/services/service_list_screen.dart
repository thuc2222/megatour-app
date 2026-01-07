// lib/screens/services/service_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/search_provider.dart';
import '../../models/service_models.dart';
import 'package:megatour_app/utils/context_extension.dart';

class ServiceListScreen extends StatefulWidget {
  final String serviceType;
  final String title;

  ServiceListScreen({
    Key? key,
    required this.serviceType,
    required this.title,
  }) : super(key: key);

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedSort = 'price_low_high';
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().searchServices(
            serviceType: widget.serviceType,
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
      backgroundColor: Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildSortRow(),
          Expanded(child: _buildList(provider)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH + SORT
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search ${widget.title.toLowerCase()}',
          prefixIcon: Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => _searchQuery = v.isEmpty ? null : v,
        onSubmitted: (_) => _loadServices(),
      ),
    );
  }

  Widget _buildSortRow() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _sortChip('Low → High', 'price_low_high'),
          _sortChip('High → Low', 'price_high_low'),
          _sortChip('Top Rated', 'rate_high_low'),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _selectedSort == value;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedSort = value);
          _loadServices();
        },
        selectedColor: Colors.blue,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LIST
  // ---------------------------------------------------------------------------

  Widget _buildList(SearchProvider provider) {
    if (provider.isLoading && provider.services.isEmpty) {
      return Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null) {
      return Center(child: Text(provider.errorMessage!));
    }

    if (provider.services.isEmpty) {
      return Center(child: Text(context.l10n.noResultsFound));
    }

    return RefreshIndicator(
      onRefresh: () async => _loadServices(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.all(16),
        itemCount:
            provider.services.length + (provider.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.services.length) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _serviceCard(provider.services[index]);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD
  // ---------------------------------------------------------------------------

  Widget _serviceCard(ServiceModel s) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/service-detail',
          arguments: {'id': s.id, 'type': widget.serviceType},
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _imageHeader(s),
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  if (s.address != null)
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            s.address!,
                            style: TextStyle(
                                color: Colors.grey, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (s.reviewScore != null)
                        _ratingPill(s.reviewScore!, s.reviewCount),
                      _priceBlock(s),
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

  Widget _imageHeader(ServiceModel s) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      child: Stack(
        children: [
          Image.network(
            s.image ?? '',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(height: 190, color: Colors.grey[300]),
          ),
          Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          if (s.isFeatured == true)
            Positioned(
              top: 12,
              left: 12,
              child: _badge('FEATURED'),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _ratingPill(String score, int? count) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.star, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            score,
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          if (count != null)
            Text(
              ' ($count)',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _priceBlock(ServiceModel s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (s.salePrice != null)
          Text(
            '\$${s.price}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(
          '\$${s.salePrice ?? s.price}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER SHEET (unchanged logic)
  // ---------------------------------------------------------------------------

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text(context.l10n.filtersComingSoon)),
      ),
    );
  }
}
