import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service_models.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  double _searchOffset = 220.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadHomeData();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _searchOffset = 220.0 - _scrollController.offset;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToDetail(ServiceModel item) {
    String routeName = '';
    switch (item.objectModel ?? '') {
      case 'hotel': routeName = '/hotel-detail'; break;
      case 'tour':  routeName = '/tour-detail'; break;
      case 'space': routeName = '/space-detail'; break;
      case 'car':   routeName = '/car-detail'; break;
      default:      routeName = '/service-detail'; 
    }

    if (routeName.isNotEmpty) {
      Navigator.pushNamed(context, routeName, arguments: item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (homeProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => homeProvider.loadHomeData(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(homeProvider, authProvider),
                
                // Space for the Floating Search Box
                const SliverToBoxAdapter(child: SizedBox(height: 110)),

                _buildSliverSections(homeProvider),
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // Search Form (Floating)
          Positioned(
            top: _searchOffset > 85 ? _searchOffset : 85, 
            left: 0,
            right: 0,
            child: _buildSearchForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(HomeProvider provider, AuthProvider auth) {
    final banner = provider.homeData?.banner;
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF667eea),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Safe Image Loading
            if (banner?.bgImageUrl != null && banner!.bgImageUrl.isNotEmpty)
              Image.network(
                banner.bgImageUrl, 
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultGradient(),
              )
            else
              _buildDefaultGradient(),
            
            Container(color: Colors.black.withOpacity(0.35)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner?.title ?? 'Hi, ${auth.user?.firstName ?? "Explorer"} 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    banner?.subTitle ?? 'Discover your next adventure',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverSections(HomeProvider provider) {
    final data = provider.homeData;

    if (data == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text("Connecting to server...")),
      );
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // 1. Offer Block Section
        if (data.offers.isNotEmpty) _buildOfferSection(data.offers),
        
        // 2. Dynamic Service Sections
        _buildDynamicSection('Featured Hotels', data.featuredHotels, Colors.blue, Icons.hotel),
        _buildDynamicSection('Popular Tours', data.featuredTours, Colors.green, Icons.explore),
        _buildDynamicSection('Luxury Spaces', data.featuredSpaces, Colors.purple, Icons.holiday_village),
        _buildDynamicSection('Car Rentals', data.featuredCars, Colors.orange, Icons.directions_car),
        
        // Final fallback if everything is empty
        if (!provider.hasData)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text("No featured items found in Admin Panel")),
          ),
      ]),
    );
  }

  Widget _buildOfferSection(List<OfferItemModel> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Text("Special Offers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 15, bottom: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade700]),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, 3))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(offer.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(offer.desc, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  Widget _buildSearchForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: const TextField(
              readOnly: true,
              decoration: InputDecoration(
                hintText: "Search destinations...",
                prefixIcon: Icon(Icons.search, color: Colors.blue),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceItem(Icons.hotel, "Hotel", Colors.blue),
              _buildServiceItem(Icons.explore, "Tour", Colors.green),
              _buildServiceItem(Icons.holiday_village, "Space", Colors.purple),
              _buildServiceItem(Icons.directions_car, "Car", Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDynamicSection(String title, List<ServiceModel> items, Color color, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
              Text('See All', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: items.length,
            itemBuilder: (context, index) => _buildFullCard(items[index], color),
          ),
        ),
      ],
    );
  }

  Widget _buildFullCard(ServiceModel item, Color color) {
    return GestureDetector(
      onTap: () => _navigateToDetail(item),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 15, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                item.image ?? '', 
                height: 130, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.image)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.locationName ?? 'Global', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${item.price ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (item.reviewScore != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(item.reviewScore!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
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

  Widget _buildDefaultGradient() {
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])));
  }
}