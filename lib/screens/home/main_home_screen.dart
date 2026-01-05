// lib/screens/home/main_home_screen.dart

import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'news_tab.dart';
import 'bookings_tab.dart';
import 'profile_tab.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<Widget> _tabs;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    _tabs = [
      const HomeTab(),
      const NewsTab(),
      const BookingsTab(),
      ProfileTab(
        onBookingHistoryTap: () => _onTabTapped(2),
      ),
    ];

    // Animation controller for tab transitions
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Tab content
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),

          // Animated bottom navigation bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _buildAnimatedBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBottomBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
              useAppIcon: true, // ✅ Use custom app icon
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.article_rounded,
              label: 'News',
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.bookmarks_rounded,
              label: 'Trips',
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool useAppIcon = false,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon with scale and rotation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isSelected ? _scaleAnimation.value : 1.0,
                    child: Transform.rotate(
                      angle: isSelected ? _rotateAnimation.value : 0.0,
                      child: child,
                    ),
                  );
                },
                child: useAppIcon
                    ? _buildAppIcon(isSelected)
                    : Icon(
                        icon,
                        size: isSelected ? 28 : 24,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
              ),

              const SizedBox(height: 4),

              // Animated label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                child: Text(label),
              ),

              // Active indicator dot
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 4,
                  width: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Custom App Icon for Home Tab
  Widget _buildAppIcon(bool isSelected) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(),
      child: Stack(
        children: [
          // Main travel icon
          Center(
            child: Image.asset(
              'assets/icon/icon.png',
              width: isSelected ? 26 : 22,
              height: isSelected ? 26 : 22,
              fit: BoxFit.contain,
            ),
          ),

          // Animated pulse effect when selected
          if (isSelected)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(1 - _animationController.value),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// ALTERNATIVE: Floating Action Button Style
// ============================================================================

class MainHomeScreenWithFAB extends StatefulWidget {
  const MainHomeScreenWithFAB({Key? key}) : super(key: key);

  @override
  State<MainHomeScreenWithFAB> createState() => _MainHomeScreenWithFABState();
}

class _MainHomeScreenWithFABState extends State<MainHomeScreenWithFAB>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabController;

  late final List<Widget> _tabs = [
  const HomeTab(),
  const NewsTab(),
  const BookingsTab(),
  ProfileTab(
    onBookingHistoryTap: () {
      setState(() => _currentIndex = 2);
    },
  ),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: _buildFloatingHomeButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  Widget _buildFloatingHomeButton() {
  final isHome = _currentIndex == 0;

  return AnimatedScale(
    scale: isHome ? 1.1 : 1.0,
    duration: const Duration(milliseconds: 200),
    child: FloatingActionButton(
      backgroundColor: Colors.transparent,
      elevation: 0,
      highlightElevation: 0,
      onPressed: () {
        setState(() => _currentIndex = 0);
        _fabController.forward().then((_) => _fabController.reverse());
      },
      child: AnimatedBuilder(
        animation: _fabController,
        builder: (context, _) {
          return Transform.rotate(
            angle: _fabController.value * 0.5,
            child: Container(
              width: 64, // ✅ EXPLICIT SIZE
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade400,
                    Colors.blue.shade700,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}


  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(1, Icons.article_rounded, 'News'),
            const SizedBox(width: 80), // Space for FAB
            _buildNavButton(2, Icons.bookmarks_rounded, 'Trips'),
            _buildNavButton(3, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: isSelected ? 26 : 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ALTERNATIVE: Modern Card Style Navigation
// ============================================================================

class MainHomeScreenModern extends StatefulWidget {
  const MainHomeScreenModern({Key? key}) : super(key: key);

  @override
  State<MainHomeScreenModern> createState() => _MainHomeScreenModernState();
}

class _MainHomeScreenModernState extends State<MainHomeScreenModern> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  late final List<Widget> _tabs = [
  const HomeTab(),
  const NewsTab(),
  const BookingsTab(),
  ProfileTab(
    onBookingHistoryTap: () => setState(() => _currentIndex = 2),
  ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            children: _tabs,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildModernBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernBottomBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModernNavItem(
            0,
            Icons.travel_explore,
            'Explore',
            useGradient: true,
          ),
          _buildModernNavItem(1, Icons.newspaper, 'News'),
          _buildModernNavItem(2, Icons.luggage, 'Trips'),
          _buildModernNavItem(3, Icons.person, 'You'),
        ],
      ),
    );
  }

  Widget _buildModernNavItem(
    int index,
    IconData icon,
    String label, {
    bool useGradient = false,
  }) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          gradient: isSelected && useGradient
              ? LinearGradient(
                  colors: [Colors.blue.shade400, Colors.purple.shade400],
                )
              : null,
          color: isSelected && !useGradient
              ? Colors.blue.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: isSelected ? 24 : 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}