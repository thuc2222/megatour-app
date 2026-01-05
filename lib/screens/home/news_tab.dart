// lib/screens/home/news_tab.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class NewsTab extends StatefulWidget {
  const NewsTab({Key? key}) : super(key: key);

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> {
  final PageController _pageController =
      PageController(viewportFraction: 0.92);

  Timer? _autoSlideTimer;
  int _currentPage = 0;

  List<dynamic> _articles = [];
  List<dynamic> _categories = [];

  bool _loading = true;
  int? _selectedCatId;

  // ---------------------------------------------------------------------------
  // INIT / DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchArticles();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _fetchCategories() async {
    try {
      final res =
          await http.get(Uri.parse('${ApiConfig.baseUrl}news/categories'));
      final json = jsonDecode(res.body);

      if (!mounted) return;

      if (json is Map && json['data'] is List) {
        setState(() => _categories = json['data']);
      }
    } catch (_) {}
  }

  Future<void> _fetchArticles({int? catId}) async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final url = catId == null
          ? '${ApiConfig.baseUrl}news'
          : '${ApiConfig.baseUrl}news?cat_id=$catId';

      final res = await http.get(Uri.parse(url));
      final json = jsonDecode(res.body);

      if (!mounted) return;

      setState(() {
        _articles = json is Map && json['data'] is List ? json['data'] : [];
        _loading = false;
      });

      _startAutoSlide();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO SLIDE
  // ---------------------------------------------------------------------------

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();

    if (_featuredArticles.length <= 1) return;

    _autoSlideTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;

        _currentPage =
            (_currentPage + 1) % _featuredArticles.length;

        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  List<dynamic> get _featuredArticles =>
      _articles.take(5).toList();

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildCategories(),
                _buildFeatured(),
                _buildList(),
                const SliverToBoxAdapter(
                child: SizedBox(height: 140),
              ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  SliverAppBar _buildHeader() {
    return const SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        'Travel Stories',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  SliverToBoxAdapter _buildCategories() {
    if (_categories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _categoryChip(
              label: 'All',
              selected: _selectedCatId == null,
              onTap: () {
                setState(() => _selectedCatId = null);
                _fetchArticles();
              },
            ),
            ..._categories.map((c) {
              return _categoryChip(
                label: c['name'] ?? '',
                selected: _selectedCatId == c['id'],
                onTap: () {
                  setState(() => _selectedCatId = c['id']);
                  _fetchArticles(catId: c['id']);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
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
  // FEATURED AUTO SLIDER
  // ---------------------------------------------------------------------------

  SliverToBoxAdapter _buildFeatured() {
    if (_featuredArticles.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 280,
        child: PageView.builder(
          controller: _pageController,
          itemCount: _featuredArticles.length,
          onPageChanged: (i) => _currentPage = i,
          itemBuilder: (_, i) {
            final a = _featuredArticles[i];
            return GestureDetector(
              onTap: () => _openArticle(a),
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  image: a['image_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(a['image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    a['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ARTICLE LIST
  // ---------------------------------------------------------------------------

  SliverList _buildList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final a = _articles[i];
          return GestureDetector(
            onTap: () => _openArticle(a),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (a['image_url'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(18),
                      ),
                      child: Image.network(
                        a['image_url'],
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (a['category'] != null)
                            Text(
                              a['category']['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            a['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (a['created_at'] != null)
                            Text(
                              a['created_at'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: _articles.length,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  void _openArticle(dynamic article) {
    Navigator.pushNamed(
      context,
      '/article-detail',
      arguments: {'article': article},
    );
  }
}
