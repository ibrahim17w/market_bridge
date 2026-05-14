import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../lang/translations.dart';
import '../providers/locale_provider.dart';
import '../widgets/app_notification.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/cached_image.dart';
import 'store_products_screen.dart';
import 'product_detail_screen.dart';
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
  bool _productsLoading = true;
  bool _storesLoading = true;
  bool _trendingLoading = true;
  bool _sponsoredLoading = true;
  String _userName = '';
  bool _isGridView = true;

  static final List<String> _pendingViews = [];
  static Timer? _viewFlushTimer;

  @override
  void initState() {
    super.initState();
    _loadGridPreference();
    _loadUserName();
    // Load each section independently - no blocking Future.wait()
    _loadProducts();
    _loadStores();
    _loadTrending();
    _loadSponsored();
  }

  Future<void> _loadGridPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _isGridView = prefs.getBool('home_grid_view') ?? true);
  }

  Future<void> _toggleViewMode() async {
    final newMode = !_isGridView;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_grid_view', newMode);
    setState(() => _isGridView = newMode);
  }

  @override
  void dispose() {
    _viewFlushTimer?.cancel();
    _flushViews();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (mounted && user != null)
        setState(() => _userName = user['full_name'] ?? '');
    } catch (_) {}
  }

  // Each section loads independently - if one fails, others still work
  Future<void> _loadProducts() async {
    try {
      final products = await ApiService.fetchMarketplaceFeed();
      if (mounted)
        setState(() {
          _products = products;
          _productsLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _productsLoading = false);
    }
  }

  Future<void> _loadStores() async {
    try {
      final stores = await ApiService.fetchStores();
      if (mounted)
        setState(() {
          _stores = stores;
          _storesLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  Future<void> _loadTrending() async {
    try {
      final trending = await ApiService.fetchTrendingProducts();
      if (mounted)
        setState(() {
          _trendingProducts = trending.isNotEmpty ? trending : [];
          _trendingLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _trendingLoading = false);
    }
  }

  Future<void> _loadSponsored() async {
    try {
      final sponsored = await ApiService.fetchSponsoredStores();
      if (mounted)
        setState(() {
          _sponsoredStores = sponsored.isNotEmpty ? sponsored : [];
          _sponsoredLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _sponsoredLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _productsLoading = true;
      _storesLoading = true;
      _trendingLoading = true;
      _sponsoredLoading = true;
    });
    await Future.wait([
      _loadProducts(),
      _loadStores(),
      _loadTrending(),
      _loadSponsored(),
    ]);
  }

  List<dynamic> _getRecommendedProducts() {
    final recentViews = <String>[];
    final recentSearches = <String>[];
    // Use a simple fallback: random products from the feed
    if (_products.length <= 6) return List<dynamic>.from(_products);
    final random = Random();
    final indices = <int>{};
    while (indices.length < 6 && indices.length < _products.length) {
      indices.add(random.nextInt(_products.length));
    }
    return indices.map((i) => _products[i]).toList();
  }

  void _onProductTap(dynamic product) {
    _trackProductView(product);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  void _trackProductView(dynamic product) {
    final productName = product['name']?.toString() ?? '';
    if (productName.isEmpty) return;
    _pendingViews.remove(productName);
    _pendingViews.insert(0, productName);
    if (_pendingViews.length > 20) _pendingViews.removeLast();
    _viewFlushTimer?.cancel();
    _viewFlushTimer = Timer(const Duration(seconds: 2), _flushViews);
    final productId = product['id'];
    if (productId != null)
      ApiService.trackProductView(productId).catchError((_) {});
  }

  static Future<void> _flushViews() async {
    if (_pendingViews.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'recent_product_views',
      List<String>.from(_pendingViews),
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

  void _openSeeAll({
    required String title,
    required List<dynamic> items,
    required bool isStore,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SeeAllScreen(
          title: title,
          items: items,
          isStore: isStore,
          onProductTap: _onProductTap,
          onStoreTap: (store) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreProductsScreen(storeId: store['id']),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(
                                  text: "${t('welcome')} ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                TextSpan(
                                  text: 'Market Bridge',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                if (_userName.isNotEmpty)
                                  TextSpan(
                                    text: ', $_userName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isGridView ? Icons.view_list : Icons.grid_view,
                        ),
                        onPressed: _toggleViewMode,
                      ),
                      const ThemeToggle(),
                      const SizedBox(width: 2),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          icon: ValueListenableBuilder(
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

              // ── Search bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

              // ── Recommended ──
              if (!_productsLoading && _products.isNotEmpty) ...[
                _SectionHeaderSliver(
                  title: t('recommended_for_you') ?? 'Recommended for You',
                  onSeeAll: () => _openSeeAll(
                    title: t('recommended_for_you') ?? 'Recommended for You',
                    items: _getRecommendedProducts(),
                    isStore: false,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _getRecommendedProducts().length,
                      itemBuilder: (context, i) => _SmallProductCard(
                        product: _getRecommendedProducts()[i],
                        onTap: _onProductTap,
                      ),
                    ),
                  ),
                ),
              ],

              // ── Top Shops ──
              if (!_sponsoredLoading && _sponsoredStores.isNotEmpty) ...[
                _SectionHeaderSliver(
                  title: t('top_shops') ?? 'Top Shops',
                  onSeeAll: () => _openSeeAll(
                    title: t('top_shops') ?? 'Top Shops',
                    items: _sponsoredStores,
                    isStore: true,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _sponsoredStores.length,
                      itemBuilder: (context, i) => _SponsoredStoreCard(
                        store: _sponsoredStores[i],
                        onTap: (store) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StoreProductsScreen(storeId: store['id']),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Hot & Trending ──
              if (!_trendingLoading && _trendingProducts.isNotEmpty) ...[
                _SectionHeaderSliver(
                  title: t('hot_trending') ?? 'Hot & Trending',
                  onSeeAll: () => _openSeeAll(
                    title: t('hot_trending') ?? 'Hot & Trending',
                    items: _trendingProducts,
                    isStore: false,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _trendingProducts.length,
                      itemBuilder: (context, i) => _SmallProductCard(
                        product: _trendingProducts[i],
                        onTap: _onProductTap,
                        isTrending: true,
                      ),
                    ),
                  ),
                ),
              ],

              // ── Latest Products header ──
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
                      TextButton(
                        onPressed: () => _openSeeAll(
                          title: t('latest_products') ?? 'Latest Products',
                          items: _products,
                          isStore: false,
                        ),
                        child: Text(t('see_all')),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Latest Products ──
              _productsLoading
                  ? const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _products.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(child: Text('No products available')),
                    )
                  : _isGridView
                  ? _buildProductGrid(_products)
                  : _buildProductList(_products),

              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<dynamic> products) {
    final displayCount = products.length > 30 ? 30 : products.length;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) =>
              _SmallProductCard(product: products[i], onTap: _onProductTap),
          childCount: displayCount,
        ),
      ),
    );
  }

  Widget _buildProductList(List<dynamic> products) {
    final displayCount = products.length > 30 ? 30 : products.length;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProductListTile(product: products[i], onTap: _onProductTap),
          ),
          childCount: displayCount,
        ),
      ),
    );
  }
}

// ============================================================
// SEE ALL SCREEN
// ============================================================

class _SeeAllScreen extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final bool isStore;
  final void Function(dynamic) onProductTap;
  final void Function(dynamic) onStoreTap;

  const _SeeAllScreen({
    required this.title,
    required this.items,
    required this.isStore,
    required this.onProductTap,
    required this.onStoreTap,
  });

  @override
  State<_SeeAllScreen> createState() => _SeeAllScreenState();
}

class _SeeAllScreenState extends State<_SeeAllScreen> {
  bool _isGrid = true;

  void _toggleView() => setState(() => _isGrid = !_isGrid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_isGrid ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleView,
          ),
        ],
      ),
      body: _isGrid ? _buildGrid() : _buildList(),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: widget.items.length,
      itemBuilder: (context, i) {
        if (widget.isStore) {
          return _SponsoredStoreCard(
            store: widget.items[i],
            onTap: widget.onStoreTap,
          );
        }
        return _SmallProductCard(
          product: widget.items[i],
          onTap: widget.onProductTap,
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.items.length,
      itemBuilder: (context, i) {
        if (widget.isStore) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StoreListTile(
              store: widget.items[i],
              onTap: widget.onStoreTap,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ProductListTile(
            product: widget.items[i],
            onTap: widget.onProductTap,
          ),
        );
      },
    );
  }
}

// ============================================================
// WIDGETS
// ============================================================

class _SectionHeaderSliver extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeaderSliver({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
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
}

class _SmallProductCard extends StatelessWidget {
  final dynamic product;
  final void Function(dynamic) onTap;
  final bool isTrending;

  const _SmallProductCard({
    required this.product,
    required this.onTap,
    this.isTrending = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(product),
      child: Container(
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
                CachedAppImage(
                  imageUrl: product['image_url'],
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 400,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
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
                    product['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '\$${product['price']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product['shop_name'] ?? '',
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
}

class _ProductListTile extends StatelessWidget {
  final dynamic product;
  final void Function(dynamic) onTap;

  const _ProductListTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(product),
      child: Container(
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
        child: Row(
          children: [
            CachedAppImage(
              imageUrl: product['image_url'],
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${product['price']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product['shop_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreListTile extends StatelessWidget {
  final dynamic store;
  final void Function(dynamic) onTap;

  const _StoreListTile({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(store),
      child: Container(
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
        child: Row(
          children: [
            CachedAppImage(
              imageUrl: store['image_url'],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              memCacheWidth: 200,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store['city'] ?? ''}, ${store['country'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsoredStoreCard extends StatelessWidget {
  final dynamic store;
  final void Function(dynamic) onTap;

  const _SponsoredStoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(store),
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
            CachedAppImage(
              imageUrl: store['image_url'],
              width: 120,
              height: 80,
              fit: BoxFit.cover,
              memCacheWidth: 240,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
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

// ============================================================
// SEARCH BOTTOM SHEET
// ============================================================

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
