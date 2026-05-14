import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/theme_toggle.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'store_products_screen.dart';
import 'my_store_screen.dart';
import '../lang/translations.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  List<dynamic> stores = [];
  bool isLoading = true;
  String error = '';
  String? userRole;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final data = await ApiService.fetchStores();
      final role = await ApiService.getUserRole();
      setState(() {
        stores = data;
        userRole = role;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> openMap(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Bridge'),
        actions: [
          if (userRole == 'store_owner')
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyStoreScreen()),
                );
              },
              icon: const Icon(Icons.inventory_2, color: Colors.white),
              label: const Text(
                'My Store',
                style: TextStyle(color: Colors.white),
              ),
            ),
          const ThemeToggle(),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(child: Text('Error: $error'))
          : ListView.builder(
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.store,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      store['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${store['city']} - ${store['village']}\n${store['phone'] ?? ''}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreProductsScreen(
                            storeId: store['id'],
                            storeName: store['name'],
                          ),
                        ),
                      );
                    },
                    trailing: IconButton(
                      icon: Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        if (store['lat'] != null && store['lng'] != null) {
                          openMap(
                            double.parse(store['lat'].toString()),
                            double.parse(store['lng'].toString()),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
