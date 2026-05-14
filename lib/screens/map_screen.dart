import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../lang/translations.dart';
import 'store_products_screen.dart';

class MapScreen extends StatefulWidget {
  final LatLng? target;
  const MapScreen({super.key, this.target});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _stores = [];
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    if (widget.target == null) {
      _moveToCurrentLocation();
    } else {
      setState(() => _locating = false);
    }
    _loadStores();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(latLng, 15);
      });
      setState(() => _locating = false);
    } catch (e) {
      setState(() => _locating = false);
    }
  }

  Future<void> _loadStores() async {
    try {
      final stores = await ApiService.fetchStores();
      if (mounted) {
        setState(() {
          _stores = stores
              .where((s) => s['lat'] != null && s['lng'] != null)
              .toList();
        });
      }
    } catch (e) {
      // Stores just won't show if this fails
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.target != null ? t('store_location') : t('explore')),
        actions: [
          if (_locating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.target ?? const LatLng(33.510414, 36.278336),
          initialZoom: widget.target != null ? 16 : 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.marketbridge.app',
          ),
          MarkerLayer(
            markers: _stores.map((store) {
              final lat = double.tryParse(store['lat'].toString()) ?? 0;
              final lng = double.tryParse(store['lng'].toString()) ?? 0;
              final isTarget =
                  widget.target != null &&
                  (lat - widget.target!.latitude).abs() < 0.0001 &&
                  (lng - widget.target!.longitude).abs() < 0.0001;
              final imageUrl = store['image_url'] as String?;

              return Marker(
                point: LatLng(lat, lng),
                width: 120,
                height: 90,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreProductsScreen(storeId: store['id']),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shop name label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isTarget
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          store['name'] ?? t('store'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isTarget
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // FIX: Show shop image instead of GPS pin
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                          border: Border.all(
                            color: isTarget
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.store,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.store,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: widget.target == null
          ? FloatingActionButton.small(
              onPressed: _moveToCurrentLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
            )
          : null,
    );
  }
}
