// lib/screens/home/home_tab.dart
// UPDATED: Linked Boat, Car, and Space detail/list screens

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/home_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service_models.dart';

import '../services/service_list_screen.dart';
import '../services/service_detail_screen.dart';
import '../services/tour_list_screen.dart';
import '../services/tour_detail_screen.dart';
import '../services/event_list_screen.dart';
import '../services/space_list_screen.dart';
import '../services/space_detail_screen.dart'; // NEW
import '../services/car_list_screen.dart';
import '../services/car_detail_screen.dart'; // NEW
import '../services/boat_list_screen.dart'; // NEW

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

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  void _navigateToDetail(ServiceModel item) {
    switch (item.objectModel) {
      case 'tour':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TourDetailScreen(tourId: item.id),
          ),
        );
        break;

      case 'hotel':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailScreen(
              serviceId: item.id,
              serviceType: 'hotel',
            ),
          ),
        );
        break;

      case 'space': // LINKED: Featured Space
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpaceDetailScreen(spaceId: item.id),
          ),
        );
        break;

      case 'car': // LINKED: Featured Car
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CarDetailScreen(carId: item.id),
          ),
        );
        break;

      default:
        break;
    }
  }

  void _openTourList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TourListScreen(title: 'Tours')),
    );
  }

  void _openHotelList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ServiceListScreen(
          serviceType: 'hotel',
          title: 'Hotels',
        ),
      ),
    );
  }

  void _openEventList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventListScreen()),
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (homeProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
                const SliverToBoxAdapter(child: SizedBox(height: 110)),
                _buildSliverSections(homeProvider),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
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

  // ------------------------------------------------------------
  // APP BAR
  // ------------------------------------------------------------

  Widget _buildSliverAppBar(HomeProvider provider, AuthProvider auth) {
    final banner = provider.homeData?.banner;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF667eea),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        backgroundImage: auth.user?.avatarUrl != null
                            ? NetworkImage(auth.user!.avatarUrl!)
                            : null,
                        child: auth.user?.avatarUrl == null
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hi, ${auth.user?.firstName ?? "Explorer"} 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (banner?.title != null && banner!.title.isNotEmpty)
                    Text(
                      banner.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    banner?.subTitle ?? 'Discover your next adventure',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTIONS
  // ------------------------------------------------------------

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
        if (data.offers.isNotEmpty) _buildOfferSection(data.offers),

        _buildDynamicSection(
          title: 'Featured Hotels',
          items: data.featuredHotels,
          color: Colors.blue,
          icon: Icons.hotel,
        ),

        _buildDynamicSection(
          title: 'Popular Tours',
          items: data.featuredTours,
          color: Colors.green,
          icon: Icons.explore,
          onSeeAll: _openTourList,
        ),

        _buildDynamicSection(
          title: 'Luxury Spaces',
          items: data.featuredSpaces,
          color: Colors.purple,
          icon: Icons.holiday_village,
        ),

        _buildDynamicSection(
          title: 'Car Rentals',
          items: data.featuredCars,
          color: Colors.orange,
          icon: Icons.directions_car,
        ),
      ]),
    );
  }

  // ------------------------------------------------------------
  // SEARCH FORM (UPDATED WITH LINKS)
  // ------------------------------------------------------------

  Widget _buildSearchForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
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
          
          SizedBox(
            height: 75,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _serviceShortcut(
                  icon: Icons.hotel,
                  label: "Hotel",
                  color: Colors.blue,
                  onTap: _openHotelList,
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.explore,
                  label: "Tour",
                  color: Colors.green,
                  onTap: _openTourList,
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.holiday_village,
                  label: "Space",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SpaceListScreen()),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.directions_car,
                  label: "Car",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CarListScreen()),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.confirmation_number,
                  label: "Event",
                  color: Colors.pink,
                  onTap: _openEventList,
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.directions_boat,
                  label: "Boat",
                  color: Colors.cyan,
                  onTap: () { // LINKED: Boat search item
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BoatListScreen()),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _serviceShortcut(
                  icon: Icons.credit_card,
                  label: "Visa",
                  color: Colors.indigo,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // DYNAMIC SECTIONS
  // ------------------------------------------------------------

  Widget _buildDynamicSection({
    required String title,
    required List<ServiceModel> items,
    required Color color,
    required IconData icon,
    VoidCallback? onSeeAll,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _buildFullCard(items[index], color),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                item.image ?? '',
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.locationName ?? 'Global',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${item.price ?? 0}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // OFFERS
  // ------------------------------------------------------------

  Widget _buildOfferSection(List<OfferItemModel> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Text(
            "Special Offers",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offer.desc,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
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

  Widget _buildDefaultGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
    );
  }
}