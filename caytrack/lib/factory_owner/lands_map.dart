import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'factory_owner_drawer.dart';

// Custom colors matching Factory Owner Dashboard
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color cardBackground = Colors.white;
  static const Color secondaryText = Color(0xFF6A798A);
  static const Color secondaryColor = Color(0xFF6AD96A);
  
  // Header gradient colors
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

class FactoryLocationsPage extends StatefulWidget {
  const FactoryLocationsPage({super.key});

  @override
  State<FactoryLocationsPage> createState() => _FactoryLocationsPageState();
}

class _FactoryLocationsPageState extends State<FactoryLocationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  
  // Header variables
  String _loggedInUserName = 'Loading...';
  String _factoryName = 'Loading...';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;

  // Factory locations data
  List<Map<String, dynamic>> _factoryLocations = [];
  List<Map<String, dynamic>> _filteredFactoryLocations = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Map state
  LatLng? _centerLocation;
  double _zoomLevel = 10.0;
  LatLng? _selectedLocation;
  Map<String, dynamic>? _selectedFactory;

  // Filter state
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProvince;
  bool _showFilters = false;

  // Province data for Sri Lanka
  final List<String> _provinces = [
    'All Provinces',
    'Western Province',
    'Central Province',
    'Southern Province',
    'Eastern Province',
    'Northern Province',
    'North Western Province',
    'North Central Province',
    'Uva Province',
    'Sabaragamuwa Province',
  ];

  // Tile layers
  final List<Map<String, String>> _tileLayers = [
    {
      'name': 'OpenStreetMap Standard',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors'
    },
    {
      'name': 'OpenStreetMap Black & White',
      'url': 'https://tiles.wmflabs.org/bw-mapnik/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors'
    },
  ];
  int _selectedTileLayer = 0;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    _fetchFactoryLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchHeaderData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final String uid = user.uid;

    try {
      // Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _userRole = userData?['role'] ?? 'Factory Owner';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
      // Fetch Factory Name from 'factories' collection
      final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(uid).get();
      if (factoryDoc.exists) {
        setState(() {
          _factoryName = factoryDoc.data()?['factoryName'] ?? 'Factory Name Missing';
        });
      }

    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _factoryName = 'Data Error';
      });
    }
  }

  void _fetchFactoryLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch all documents from land_location collection
      final QuerySnapshot querySnapshot = await _firestore.collection('land_location').get();
      
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _factoryLocations = [];
          _filteredFactoryLocations = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> locations = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Only include documents with valid latitude and longitude
        if (data['latitude'] != null && data['longitude'] != null) {
          // Fetch factory details for this user
          final userId = data['userId']?.toString() ?? doc.id;
          String factoryName = 'Unknown Factory';
          String ownerName = 'Unknown Owner';
          
          try {
            // Try to get factory name from factories collection
            final factoryDoc = await _firestore.collection('factories').doc(userId).get();
            if (factoryDoc.exists) {
              factoryName = factoryDoc.data()?['factoryName'] ?? 'Unknown Factory';
            }
            
            // Try to get owner name from users collection
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              ownerName = userDoc.data()?['name'] ?? 'Unknown Owner';
            }
          } catch (e) {
            debugPrint("Error fetching factory/user details: $e");
          }

          // Parse coordinates
          double? latitude;
          double? longitude;
          
          if (data['latitude'] is String) {
            latitude = double.tryParse(data['latitude'] as String);
          } else if (data['latitude'] is num) {
            latitude = (data['latitude'] as num).toDouble();
          }
          
          if (data['longitude'] is String) {
            longitude = double.tryParse(data['longitude'] as String);
          } else if (data['longitude'] is num) {
            longitude = (data['longitude'] as num).toDouble();
          }

          if (latitude != null && longitude != null) {
            locations.add({
              'id': doc.id,
              'userId': userId,
              'latitude': latitude,
              'longitude': longitude,
              'latitudeString': data['latitudeString']?.toString() ?? latitude.toStringAsFixed(6),
              'longitudeString': data['longitudeString']?.toString() ?? longitude.toStringAsFixed(6),
              'address': data['address']?.toString() ?? 'Address not available',
              'factoryName': factoryName,
              'ownerName': ownerName,
              'locationType': data['locationType']?.toString() ?? 'manual',
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            });
          }
        }
      }

      // Calculate center of all locations
      if (locations.isNotEmpty) {
        final avgLat = locations.map((l) => l['latitude'] as double).reduce((a, b) => a + b) / locations.length;
        final avgLng = locations.map((l) => l['longitude'] as double).reduce((a, b) => a + b) / locations.length;
        _centerLocation = LatLng(avgLat, avgLng);
      } else {
        _centerLocation = const LatLng(7.8731, 80.7718); // Sri Lanka center
      }

      setState(() {
        _factoryLocations = locations;
        _filteredFactoryLocations = List.from(locations);
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error fetching factory locations: $e");
      setState(() {
        _errorMessage = "Failed to load factory locations";
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_factoryLocations);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((factory) {
        final factoryName = factory['factoryName']?.toString().toLowerCase() ?? '';
        final ownerName = factory['ownerName']?.toString().toLowerCase() ?? '';
        final address = factory['address']?.toString().toLowerCase() ?? '';
        return factoryName.contains(searchLower) ||
               ownerName.contains(searchLower) ||
               address.contains(searchLower);
      }).toList();
    }

    // Apply province filter
    if (_selectedProvince != null && _selectedProvince != 'All Provinces') {
      // This is a simplified province filter based on address
      filtered = filtered.where((factory) {
        final address = factory['address']?.toString().toLowerCase() ?? '';
        return address.contains(_selectedProvince!.toLowerCase());
      }).toList();
    }

    setState(() {
      _filteredFactoryLocations = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedProvince = null;
      _searchController.clear();
      _showFilters = false;
      _filteredFactoryLocations = List.from(_factoryLocations);
    });
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context); // Close drawer
    // Handle navigation based on route name
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 15),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName, 
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Factory Name: $_factoryName \n($_userRole)', 
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25), 
          
          // Page Title
          Text(
            'Factory Locations',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: const InputDecoration(
                      hintText: 'Search factories, owners...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.secondaryText),
                    ),
                    style: const TextStyle(color: AppColors.darkText),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Toggle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
              ),
            ],
          ),
          
          // Filters (Collapsible)
          if (_showFilters) ...[
            const SizedBox(height: 12),
            
            // Province Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Province',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _provinces.map((province) {
                    return DropdownMenuItem(
                      value: province,
                      child: Text(province),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Clear Filters Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Container(
      height: 400,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _centerLocation ?? const LatLng(7.8731, 80.7718),
            zoom: _zoomLevel,
            onTap: (position, latLng) {
              setState(() {
                _selectedLocation = null;
                _selectedFactory = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileLayers[_selectedTileLayer]['url'],
              userAgentPackageName: 'com.example.factory_locations',
            ),
            
            // Markers for all factory locations
            MarkerLayer(
              markers: _filteredFactoryLocations.map((factory) {
                final latLng = LatLng(factory['latitude'] as double, factory['longitude'] as double);
                final isSelected = _selectedFactory != null && _selectedFactory!['id'] == factory['id'];
                
                return Marker(
                  point: latLng,
                  width: isSelected ? 50 : 40,
                  height: isSelected ? 50 : 40,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLocation = latLng;
                        _selectedFactory = factory;
                      });
                      // Center map on selected location
                      _mapController.move(latLng, _zoomLevel);
                    },
                    child: Icon(
                      Icons.factory,
                      color: isSelected ? AppColors.warningOrange : AppColors.primaryBlue,
                      size: isSelected ? 40 : 30,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            // Selected location marker
            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation!,
                    width: 50,
                    height: 50,
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.accentRed,
                      size: 40,
                    ),
                  ),
                ],
              ),
            
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _tileLayers[_selectedTileLayer]['attribution']!,
                  onTap: () => launchUrlString('https://openstreetmap.org/copyright'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Factories (${_filteredFactoryLocations.length} found)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _filteredFactoryLocations.map((factory) {
              return _buildFactoryCard(factory);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFactoryCard(Map<String, dynamic> factory) {
    final isSelected = _selectedFactory != null && _selectedFactory!['id'] == factory['id'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFactory = factory;
          _selectedLocation = LatLng(factory['latitude'] as double, factory['longitude'] as double);
        });
        // Center map on this factory
        _mapController.move(_selectedLocation!, _zoomLevel);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.factory,
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factory['factoryName'] ?? 'Unknown Factory',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${factory['ownerName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            factory['address'] ?? 'Address not available',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.darkText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Selected',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFactoryDetails() {
    if (_selectedFactory == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Factory Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedFactory = null;
                    _selectedLocation = null;
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          _buildDetailRow('Factory Name', _selectedFactory!['factoryName'] ?? 'N/A'),
          _buildDetailRow('Owner Name', _selectedFactory!['ownerName'] ?? 'N/A'),
          _buildDetailRow('Address', _selectedFactory!['address'] ?? 'N/A'),
          _buildDetailRow('Latitude', _selectedFactory!['latitudeString'] ?? 'N/A'),
          _buildDetailRow('Longitude', _selectedFactory!['longitudeString'] ?? 'N/A'),
          _buildDetailRow('Location Type', _selectedFactory!['locationType'] ?? 'manual'),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final lat = _selectedFactory!['latitudeString'];
                    final lng = _selectedFactory!['longitudeString'];
                    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                    if (await canLaunchUrlString(url)) {
                      await launchUrlString(url);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          _auth.signOut();
          Navigator.pop(context);
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          // Header
          _buildDashboardHeader(context),
          
          // Content
          Expanded(
            child: Column(
              children: [
                // Filters Section
                _buildFilterSection(),
                
                // Map Section
                _buildMapSection(),
                
                // Selected Factory Details
                _buildSelectedFactoryDetails(),
                
                // Factories List or Loading/Error States
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryBlue),
                              const SizedBox(height: 16),
                              const Text(
                                'Loading factory locations...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _fetchFactoryLocations,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : _filteredFactoryLocations.isEmpty
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    margin: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _searchController.text.isNotEmpty || _selectedProvince != null
                                            ? Icons.search_off
                                            : Icons.factory,
                                          size: 64,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchController.text.isNotEmpty || _selectedProvince != null
                                            ? 'No Matching Factories Found'
                                            : 'No Factory Locations Found',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.darkText,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchController.text.isNotEmpty || _selectedProvince != null
                                            ? 'Try adjusting your search or filters to find what you\'re looking for.'
                                            : 'No factory locations have been saved to the database yet.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (_searchController.text.isNotEmpty || _selectedProvince != null)
                                          const SizedBox(height: 16),
                                        if (_searchController.text.isNotEmpty || _selectedProvince != null)
                                          ElevatedButton.icon(
                                            onPressed: _clearFilters,
                                            icon: const Icon(Icons.clear_all, size: 16),
                                            label: const Text('Clear Filters'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primaryBlue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: _buildFactoryList(),
                                ),
                ),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}