import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/search_provider.dart';
import '../../models/service_models.dart';

class ServiceListScreen extends StatefulWidget {
  final String serviceType;
  final String title;

  const ServiceListScreen({
    Key? key,
    required this.serviceType,
    required this.title,
  }) : super(key: key);

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  String? _searchText;
  String _selectedSort = 'price_low_high';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      _searchText = args?['keyword'];
      _searchCtrl.text = _searchText ?? '';

      _loadServices();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  void _loadServices({bool loadMore = false}) {
    context.read<SearchProvider>().searchServices(
          serviceType: widget.serviceType,
          locationName: _searchText,
          orderBy: _selectedSort,
          loadMore: loadMore,
        );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchProvider>().loadMore();
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          _buildSearchBar(provider),
          _buildSortRow(),
          Expanded(child: _buildList(provider)),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(SearchProvider provider) {
    final suggestions = provider.services
        .map((s) => s.address ?? s.locationName)
        .whereType<String>()
        .toSet()
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Autocomplete<String>(
        optionsBuilder: (value) {
          if (value.text.isEmpty) return const Iterable<String>.empty();
          return suggestions.where(
            (s) => s.toLowerCase().contains(value.text.toLowerCase()),
          );
        },
        onSelected: (v) {
          _searchText = v;
          _searchCtrl.text = v;
          _loadServices();
        },
        fieldViewBuilder: (_, controller, focusNode, __) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search hotel or location',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (v) {
              _searchText = v.isEmpty ? null : v;
            },
            onSubmitted: (_) => _loadServices(),
          );
        },
      ),
    );
  }

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildList(SearchProvider provider) {
    if (provider.isLoading && provider.services.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.services.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.services.length,
      itemBuilder: (_, i) => _hotelCard(provider.services[i]),
    );
  }

  // ============================================================
  // CARD (FEATURED + SALE + STAR)
  // ============================================================

  Widget _hotelCard(ServiceModel s) {
    final int stars = s.safeStar;
    final bool hasSale = s.salePrice != null && s.salePrice != s.price;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/service-detail',
          arguments: {'id': s.id, 'type': widget.serviceType},
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE + BADGES
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    s.image ?? '',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                // FEATURED RIBBON
                if (s.isFeatured == 1)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                // STAR BADGE
                if (stars > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star,
                              size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            stars.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (s.address != null || s.locationName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.address ?? s.locationName!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // PRICE ROW
                  Row(
                    children: [
                      if (hasSale)
                        Text(
                          '\$${s.price}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                          ),
                        ),
                      if (hasSale) const SizedBox(width: 8),
                      Text(
                        '\$${hasSale ? s.salePrice : s.price}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Spacer(),

                      if (s.reviewScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.reviewScore!,
                            style: const TextStyle(color: Colors.white),
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

  // ============================================================
  // SORT
  // ============================================================

  Widget _buildSortRow() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedSort = value);
          _loadServices();
        },
      ),
    );
  }
}
