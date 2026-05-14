import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../lang/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/app_notification.dart';
import '../widgets/theme_toggle.dart';
import 'store_products_screen.dart';
import 'map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _products = [];
  List<dynamic> _stores = [];
  List<dynamic> _trendingProducts = [];
  List<dynamic> _sponsoredStores = [];
  List<dynamic> _recommendedProducts = [];
  bool _isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (mounted && user != null) {
        setState(() => _userName = user['full_name'] ?? '');
      }
    } catch (_) {
      // Guest user, leave empty
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.fetchMarketplaceFeed(),
        ApiService.fetchStores(),
        ApiService.fetchTrendingProducts(),
        ApiService.fetchSponsoredStores(),
      ]);

      final allProducts = results[0] as List<dynamic>;
      final allStores = results[1] as List<dynamic>;
      final trending = results[2] as List<dynamic>;
      final sponsored = results[3] as List<dynamic>;

      final recommended = await _getRecommendedProducts(allProducts);

      if (mounted) {
        setState(() {
          _products = allProducts;
          _stores = allStores;
          _trendingProducts = trending.isNotEmpty
              ? trending
              : _generateTrending(allProducts);
          _sponsoredStores = sponsored.isNotEmpty
              ? sponsored
              : _pickTopStores(allStores);
          _recommendedProducts = recommended;
          _isLoading = false;
        });
      }
    } catch (e) {
      try {
        final results = await Future.wait([
          ApiService.fetchMarketplaceFeed(),
          ApiService.fetchStores(),
        ]);
        if (mounted) {
          setState(() {
            _products = results[0];
            _stores = results[1];
            _trendingProducts = _generateTrending(results[0]);
            _sponsoredStores = _pickTopStores(results[1]);
            _recommendedProducts = _getRandomProducts(results[0], 6);
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<List<dynamic>> _getRecommendedProducts(
    List<dynamic> allProducts,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final recentViews = prefs.getStringList('recent_product_views') ?? [];
    final recentSearches = prefs.getStringList('recent_searches') ?? [];

    if (recentViews.isEmpty && recentSearches.isEmpty) {
      return _getRandomProducts(allProducts, 6);
    }

    final scoredProducts = <Map<String, dynamic>>[];

    for (final product in allProducts) {
      double score = 0;
      final productName = (product['name'] ?? '').toString().toLowerCase();
      final productDesc = (product['description'] ?? '')
          .toString()
          .toLowerCase();
      final shopName = (product['shop_name'] ?? '').toString().toLowerCase();

      for (final view in recentViews) {
        final viewLower = view.toLowerCase();
        if (productName.contains(viewLower) ||
            viewLower.contains(productName)) {
          score += 3;
        }
        if (shopName.contains(viewLower)) {
          score += 1;
        }
      }

      for (final search in recentSearches) {
        final searchLower = search.toLowerCase();
        if (productName.contains(searchLower) ||
            productDesc.contains(searchLower)) {
          score += 2;
        }
      }

      if (score > 0) {
        scoredProducts.add({'product': product, 'score': score});
      }
    }

    scoredProducts.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );

    final recommended = scoredProducts
        .take(6)
        .map((e) => e['product']!)
        .toList();

    if (recommended.length < 6) {
      final usedIds = recommended.map((p) => p['id']).toSet();
      final remaining = allProducts
          .where((p) => !usedIds.contains(p['id']))
          .toList();
      remaining.shuffle(Random());
      recommended.addAll(remaining.take(6 - recommended.length));
    }

    return recommended;
  }

  List<dynamic> _generateTrending(List<dynamic> products) {
    final shuffled = List<dynamic>.from(products)..shuffle(Random());
    return shuffled.take(8).toList();
  }

  List<dynamic> _pickTopStores(List<dynamic> stores) {
    final shuffled = List<dynamic>.from(stores)..shuffle(Random());
    return shuffled.take(5).toList();
  }

  List<dynamic> _getRandomProducts(List<dynamic> products, int count) {
    final shuffled = List<dynamic>.from(products)..shuffle(Random());
    return shuffled.take(count).toList();
  }

  void _onProductTap(dynamic product) {
    _trackProductView(product);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreProductsScreen(storeId: product['shop_id']),
      ),
    );
  }

  Future<void> _trackProductView(dynamic product) async {
    final prefs = await SharedPreferences.getInstance();
    final recentViews = prefs.getStringList('recent_product_views') ?? [];
    final productName = product['name']?.toString() ?? '';

    recentViews.remove(productName);
    recentViews.insert(0, productName);
    if (recentViews.length > 20) recentViews.removeLast();

    await prefs.setStringList('recent_product_views', recentViews);
  }

  void _openStoreOnMap(dynamic store) {
    final lat = double.tryParse(store['lat']?.toString() ?? '');
    final lng = double.tryParse(store['lng']?.toString() ?? '');
    if (lat == null || lng == null) {
      showAppNotification(
        context,
        message: 'Location not available for this shop',
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapScreen(target: LatLng(lat, lng))),
    );
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // Theme + Language toggles in top-right
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const ThemeToggle(),
                      const SizedBox(width: 8),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: ValueListenableBuilder<Locale>(
                            valueListenable: localeNotifier,
                            builder: (_, locale, __) => Text(
                              locale.languageCode.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          onPressed: () => showLanguagePicker(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Centered greeting header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _userName.isNotEmpty
                            ? '${t('welcome')}, $_userName!'
                            : t('welcome'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Market Bridge',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search bar with filter — FIX: visible text color
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t('search'),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // FIX: Filter button with visible text on both light & dark
                          Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  showAppNotification(
                                    context,
                                    message: 'Filters coming soon',
                                    isSuccess: true,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.tune,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        t('filter') ?? 'Filter',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Recommended for You
              if (_recommendedProducts.isNotEmpty) ...[
                _buildSectionHeader(
                  t('recommended_for_you') ?? 'Recommended for You',
                  () {},
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _recommendedProducts.length,
                      itemBuilder: (context, i) =>
                          _buildSmallProductCard(_recommendedProducts[i]),
                    ),
                  ),
                ),
              ],

              // Sponsored / Top Shops
              if (_sponsoredStores.isNotEmpty) ...[
                _buildSectionHeader(t('top_shops') ?? 'Top Shops', () {}),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _sponsoredStores.length,
                      itemBuilder: (context, i) =>
                          _buildSponsoredStoreCard(_sponsoredStores[i]),
                    ),
                  ),
                ),
              ],

              // Hot / Trending
              if (_trendingProducts.isNotEmpty) ...[
                _buildSectionHeader(
                  t('hot_trending') ?? 'Hot & Trending',
                  () {},
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _trendingProducts.length,
                      itemBuilder: (context, i) => _buildSmallProductCard(
                        _trendingProducts[i],
                        isTrending: true,
                      ),
                    ),
                  ),
                ),
              ],

              // Latest Products header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        t('latest_products'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(onPressed: () {}, child: Text(t('see_all'))),
                    ],
                  ),
                ),
              ),

              // Latest Products — same small cards as other sections
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: _isLoading
                    ? const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.68,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final p = _products[i];
                          return _buildSmallProductCard(p);
                        }, childCount: _products.length),
                      ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: Text(t('see_all'))),
          ],
        ),
      ),
    );
  }

  /// Small horizontal card — used for Recommended, Trending, AND Latest Products
  Widget _buildSmallProductCard(dynamic p, {bool isTrending = false}) {
    return GestureDetector(
      onTap: () => _onProductTap(p),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Container(
                    height: 110,
                    width: 150,
                    color: Colors.grey.shade200,
                    child: p['image_url'] != null
                        ? Image.network(
                            p['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image, color: Colors.grey),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
                if (isTrending)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'HOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '\$${p['price']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p['shop_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sponsored store card
  Widget _buildSponsoredStoreCard(dynamic store) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoreProductsScreen(storeId: store['id']),
        ),
      ),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 80,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                image: store['image_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(store['image_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: store['image_url'] == null
                  ? Icon(Icons.store, color: Colors.grey.shade400, size: 32)
                  : null,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                store['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TOP',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Search bottom sheet placeholder
class SearchBottomSheet extends StatelessWidget {
  const SearchBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: t('search'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Text(
                'Search coming soon',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
