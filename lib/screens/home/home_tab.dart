import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/home_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service_models.dart';

import '../services/service_list_screen.dart';
import '../services/service_detail_screen.dart';
import '../services/tour_list_screen.dart';
import '../services/tour_detail_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  double _searchOffset = 220.0;
  String? _keyword;

  late final AnimationController _animCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _animCtrl.forward();
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
    _scrollController.dispose();
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // NAVIGATION (KEYWORD PASSED SAFELY)
  // ============================================================

  void _openService(String type, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceListScreen(
          serviceType: type,
          title: title,
        ),
        settings: RouteSettings(
          arguments: {
            'keyword': _keyword, // ✅ SAFE
          },
        ),
      ),
    );
  }

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
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final auth = context.watch<AuthProvider>();

    if (home.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => home.loadHomeData(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(home, auth),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
                _buildSliverSections(home),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          /// 🔍 SEARCH FORM (LOWER, CLICKABLE, ANIMATED)
          Positioned(
            top: _searchOffset > 95 ? _searchOffset : 95,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fade,
              child: _buildSearchForm(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

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
              // 🔹 USER ROW
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

              // 🔹 BANNER TITLE (SECONDARY)
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

              // 🔹 SUBTITLE
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

  // ============================================================
  // SEARCH FORM (REAL FLOW)
  // ============================================================

  Widget _buildSearchForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search location (Paris, New York...)',
              prefixIcon: Icon(Icons.location_on, color: Colors.blue),
              border: InputBorder.none,
            ),
            onChanged: (v) => _keyword = v.trim().isEmpty ? null : v.trim(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _serviceShortcut(
                icon: Icons.hotel,
                label: "Hotel",
                color: Colors.blue,
                onTap: () => _openService('hotel', 'Hotels'),
              ),
              _serviceShortcut(
                icon: Icons.explore,
                label: "Tour",
                color: Colors.green,
                onTap: () => _openService('tour', 'Tours'),
              ),
              _serviceShortcut(
                icon: Icons.holiday_village,
                label: "Space",
                color: Colors.purple,
                onTap: () => _openService('space', 'Spaces'),
              ),
              _serviceShortcut(
                icon: Icons.directions_car,
                label: "Car",
                color: Colors.orange,
                onTap: () => _openService('car', 'Cars'),
              ),
            ],
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
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENT SECTIONS (UNCHANGED)
  // ============================================================

  Widget _buildSliverSections(HomeProvider provider) {
    final data = provider.homeData;
    if (data == null) {
      return const SliverFillRemaining(
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

  Widget _buildOfferSection(List<OfferItemModel> offers) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        itemCount: offers.length,
        itemBuilder: (_, i) {
          final o = offers[i];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(o.desc,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDynamicSection({
    required String title,
    required List<ServiceModel> items,
    required Color color,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildCard(items[i], color),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ServiceModel item, Color color) {
    return GestureDetector(
      onTap: () => _navigateToDetail(item),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06), blurRadius: 12)
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(item.locationName ?? '',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text('\$${item.price ?? ''}',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultGradient() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
      ),
    );
  }
}
