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
import '../services/space_detail_screen.dart';
import '../services/car_list_screen.dart';
import '../services/car_detail_screen.dart';
import '../services/boat_list_screen.dart';
import 'package:megatour_app/utils/context_extension.dart';

class HomeTab extends StatefulWidget {
  HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _locationController = TextEditingController(); // 🟢 Added Controller
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
    _locationController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

  void _navigateToDetail(ServiceModel item) {
    switch (item.objectModel) {
      case 'tour':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TourDetailScreen(tourId: item.id)));
        break;
      case 'hotel':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: item.id, serviceType: 'hotel')));
        break;
      case 'space':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceDetailScreen(spaceId: item.id)));
        break;
      case 'car':
        Navigator.push(context, MaterialPageRoute(builder: (_) => CarDetailScreen(carId: item.id)));
        break;
      default:
        break;
    }
  }

  void _openTourList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TourListScreen(title: context.l10n.tours /* locationName: _locationController.text */)),
    );
  }

  void _openHotelList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceListScreen(
          serviceType: 'hotel',
          title: context.l10n.hotels,
          // locationName: _locationController.text // Pass search text here
        ),
      ),
    );
  }

  void _openEventList() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EventListScreen()));
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (homeProvider.isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => homeProvider.loadHomeData(),
            child: CustomScrollView(
              controller: _scrollController,
              physics: BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(homeProvider, authProvider),
                SliverToBoxAdapter(child: SizedBox(height: 110)),
                _buildSliverSections(homeProvider),
                SliverToBoxAdapter(child: SizedBox(height: 100)),
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
  // SECTIONS & WIDGETS
  // ------------------------------------------------------------

  Widget _buildSliverAppBar(HomeProvider provider, AuthProvider auth) {
    final banner = provider.homeData?.banner;
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Color(0xFF667eea),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (banner?.bgImageUrl != null && banner!.bgImageUrl.isNotEmpty)
              Image.network(banner.bgImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildDefaultGradient())
            else
              _buildDefaultGradient(),
            Container(color: Colors.black.withOpacity(0.35)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22, backgroundColor: Colors.white,
                        backgroundImage: auth.user?.avatarUrl != null ? NetworkImage(auth.user!.avatarUrl!) : null,
                        child: auth.user?.avatarUrl == null ? Icon(Icons.person, color: Colors.grey) : null,
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Hi, ${auth.user?.firstName ?? "Explorer"} 👋', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  SizedBox(height: 14),
                  if (banner?.title != null) Text(banner!.title, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text(banner?.subTitle ?? 'Discover your next adventure', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
    if (data == null) return SliverFillRemaining(hasScrollBody: false, child: Center(child: Text(context.l10n.connecting)));

    return SliverList(
      delegate: SliverChildListDelegate([
        if (data.offers.isNotEmpty) _buildOfferSection(data.offers),
        _buildDynamicSection(title: context.l10n.featuredHotels, items: data.featuredHotels, color: Colors.blue, icon: Icons.hotel),
        _buildDynamicSection(title: context.l10n.popularTours, items: data.featuredTours, color: Colors.green, icon: Icons.explore, onSeeAll: _openTourList),
        _buildDynamicSection(title: context.l10n.luxurySpaces, items: data.featuredSpaces, color: Colors.purple, icon: Icons.holiday_village),
        _buildDynamicSection(title: context.l10n.carRentals, items: data.featuredCars, color: Colors.orange, icon: Icons.directions_car),
      ]),
    );
  }

  // 🟢 FIXED: Search is now interactive
  Widget _buildSearchForm() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: Offset(0, 8))]),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _locationController,
              readOnly: false, // 🟢 Enabled typing
              decoration: InputDecoration(hintText: context.l10n.searchDestinations, prefixIcon: Icon(Icons.search, color: Colors.blue), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 15)),
              onSubmitted: (_) => _openHotelList(), // Trigger search
            ),
          ),
          SizedBox(height: 15),
          SizedBox(
            height: 75,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _serviceShortcut(icon: Icons.hotel, label: context.l10n.hotel, color: Colors.blue, onTap: _openHotelList),
                SizedBox(width: 12),

                _serviceShortcut(icon: Icons.explore, label: context.l10n.tour, color: Colors.green, onTap: _openTourList),
                SizedBox(width: 12),

                _serviceShortcut(icon: Icons.holiday_village, label: context.l10n.space, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SpaceListScreen()))),
                SizedBox(width: 12),

                _serviceShortcut(icon: Icons.directions_car, label: context.l10n.car, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarListScreen()))),
                SizedBox(width: 12),

                _serviceShortcut(icon: Icons.confirmation_number, label: context.l10n.event, color: Colors.pink, onTap: _openEventList),
                SizedBox(width: 12),

                _serviceShortcut(icon: Icons.directions_boat, label: context.l10n.boat, color: Colors.cyan, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BoatListScreen()))),
                SizedBox(width: 12),
                //_serviceShortcut(icon: Icons.credit_card, label: "Visa", color: Colors.indigo, onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceShortcut({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Column(children: [Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), SizedBox(height: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));
  }

  Widget _buildOfferSection(List<OfferItemModel> offers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Text(
            context.l10n.specialOffers,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(left: 20),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              // Check if we have a valid image URL
              final hasImage = offer.thumbImage != null && offer.thumbImage!.isNotEmpty;

              return Container(
                width: 280,
                margin: EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.blue.shade400, // Fallback color
                  // 🟢 FIX: Load the image as a background
                  image: hasImage
                      ? DecorationImage(
                          image: NetworkImage(offer.thumbImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  // Use gradient as fallback if no image
                  gradient: hasImage
                      ? null
                      : LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade700],
                        ),
                ),
                child: Container(
                  // 🟢 Add a dark overlay so white text is readable on top of the image
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: hasImage
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          )
                        : null,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Align text to bottom
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        // Remove <br> tags if they exist in the desc
                        offer.desc.replaceAll('<br>', '').replaceAll('\n', ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
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

  Widget _buildDynamicSection({required String title, required List<ServiceModel> items, required Color color, required IconData icon, VoidCallback? onSeeAll}) {
    if (items.isEmpty) return SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, color: color, size: 20), SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]), if (onSeeAll != null) GestureDetector(onTap: onSeeAll, child: Text(context.l10n.seeAll, style: TextStyle(color: color, fontWeight: FontWeight.bold)))])),
      SizedBox(height: 280, child: ListView.builder(scrollDirection: Axis.horizontal, padding: EdgeInsets.only(left: 20), itemCount: items.length, itemBuilder: (context, index) => _buildFullCard(items[index], color))),
    ]);
  }

  Widget _buildFullCard(ServiceModel item, Color color) {
    return GestureDetector(onTap: () => _navigateToDetail(item), child: Container(width: 220, margin: EdgeInsets.only(right: 15, bottom: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(item.image ?? '', height: 130, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]))), Padding(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), SizedBox(height: 6), Text(item.locationName ?? 'Global', style: TextStyle(color: Colors.grey, fontSize: 12)), SizedBox(height: 12), Text('\$${item.price ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))]))])));
  }

  Widget _buildDefaultGradient() {
    return Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)])));
  }
}