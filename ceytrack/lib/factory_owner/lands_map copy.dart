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

class LandLocationsPage extends StatefulWidget {
  const LandLocationsPage({super.key});

  @override
  State<LandLocationsPage> createState() => _LandLocationsPageState();
}

class _LandLocationsPageState extends State<LandLocationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MapController _mapController = MapController();
  
  // Header variables
  String _loggedInUserName = 'Loading...';
  String _factoryName = 'Loading...';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;

  // Land locations data
  List<Map<String, dynamic>> _landLocations = [];
  List<Map<String, dynamic>> _filteredLandLocations = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Map state
  LatLng? _centerLocation;
  double _zoomLevel = 10.0;
  LatLng? _selectedLocation;
  Map<String, dynamic>? _selectedLand;

  // Filter state
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProvince;
  bool _showFilters = false;

  // Screen size responsive variables
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;
  bool _showListInLandscape = false;

  // Land photos state
  int _currentPhotoIndex = 0;
  bool _showPhotoViewer = false;
  List<String> _currentLandPhotos = [];

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
    _fetchLandLocations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScreenDimensions();
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _isPortrait = mediaQuery.orientation == Orientation.portrait;
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _userRole = userData?['role'] ?? 'Factory Owner';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
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

  void _fetchLandLocations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Map<String, dynamic>> allLocations = [];

      // Step 1: Fetch from land_location collection (coordinates only)
      final locationSnapshot = await _firestore.collection('land_location').get();
      
      // Step 2: Fetch from lands collection (land details)
      final landsSnapshot = await _firestore.collection('lands').get();

      // Create a map of userId to land details from lands collection
      Map<String, Map<String, dynamic>> landsMap = {};
      
      for (var landDoc in landsSnapshot.docs) {
        final landData = landDoc.data() as Map<String, dynamic>;
        final userId = landDoc.id;
        
        landsMap[userId] = {
          'landDetails': landData,
          'landId': landDoc.id,
        };
      }

      // Process land_location documents
      for (var locDoc in locationSnapshot.docs) {
        final locData = locDoc.data() as Map<String, dynamic>;
        
        if (locData['latitude'] != null && locData['longitude'] != null) {
          String userId = '';
          
          if (locData['userId'] != null) {
            userId = locData['userId'].toString();
          } else if (locData['owner'] != null) {
            userId = locData['owner'].toString();
          } else if (locData['user'] != null) {
            userId = locData['user'].toString();
          } else {
            userId = locDoc.id;
          }
          
          String ownerName = 'Unknown Owner';
          String contactNumber = 'N/A';
          String ownerImageUrl = '';
          
          try {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              ownerName = userData['name']?.toString() ?? 'Unknown Owner';
              contactNumber = userData['contactNumber']?.toString() ?? 'N/A';
              ownerImageUrl = userData['profileImageUrl']?.toString() ?? '';
            } else {
              if (locData['ownerName'] != null) {
                ownerName = locData['ownerName'].toString();
              }
            }
            
            double? latitude;
            double? longitude;
            
            if (locData['latitude'] is String) {
              latitude = double.tryParse(locData['latitude'] as String);
            } else if (locData['latitude'] is num) {
              latitude = (locData['latitude'] as num).toDouble();
            }
            
            if (locData['longitude'] is String) {
              longitude = double.tryParse(locData['longitude'] as String);
            } else if (locData['longitude'] is num) {
              longitude = (locData['longitude'] as num).toDouble();
            }

            if (latitude != null && longitude != null) {
              final landDetails = landsMap[userId];
              
              String displayName = "${ownerName}'s Land";
              String landName = 'Unnamed Land';
              String cropType = 'N/A';
              String landSize = 'N/A';
              String landSizeDetails = '';
              List<String> landPhotos = [];
              String province = 'N/A';
              String district = 'N/A';
              String address = 'Address not available';
              String village = 'N/A';
              String gnDivision = 'N/A';
              String agDivision = 'N/A';
              String country = 'Sri Lanka';
              String teaLandSize = 'N/A';
              String cinnamonLandSize = 'N/A';
              String landSizeUnit = 'Hectares';
              
              if (landDetails != null) {
                final details = landDetails['landDetails'];
                landName = details['landName']?.toString() ?? 'Unnamed Land';
                displayName = landName;
                cropType = details['cropType']?.toString() ?? 'N/A';
                landSize = details['landSize']?.toString() ?? 'N/A';
                landSizeDetails = details['landSizeDetails']?.toString() ?? '';
                province = details['province']?.toString() ?? 'N/A';
                district = details['district']?.toString() ?? 'N/A';
                address = details['address']?.toString() ?? 'Address not available';
                village = details['village']?.toString() ?? 'N/A';
                gnDivision = details['gnDivision']?.toString() ?? 'N/A';
                agDivision = details['agDivision']?.toString() ?? 'N/A';
                country = details['country']?.toString() ?? 'Sri Lanka';
                teaLandSize = details['teaLandSize']?.toString() ?? 'N/A';
                cinnamonLandSize = details['cinnamonLandSize']?.toString() ?? 'N/A';
                landSizeUnit = details['landSizeUnit']?.toString() ?? 'Hectares';
                
                // Get land photos from lands collection
                if (details['landPhotos'] != null && details['landPhotos'] is List) {
                  landPhotos = List<String>.from(details['landPhotos'] as List);
                }
              } else {
                address = locData['address']?.toString() ?? 'Address not available';
                if (address.contains('Lat:') && address.contains('Lng:')) {
                  address = "Location at ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}";
                }
              }
              
              allLocations.add({
                'id': locDoc.id,
                'userId': userId,
                'latitude': latitude,
                'longitude': longitude,
                'latitudeString': locData['latitudeString']?.toString() ?? latitude.toStringAsFixed(6),
                'longitudeString': locData['longitudeString']?.toString() ?? longitude.toStringAsFixed(6),
                'address': address,
                'displayName': displayName,
                'landName': landName,
                'ownerName': ownerName,
                'contactNumber': contactNumber,
                'ownerImageUrl': ownerImageUrl,
                'locationType': locData['locationType']?.toString() ?? 'manual',
                'createdAt': locData['createdAt'],
                'updatedAt': locData['updatedAt'],
                'cropType': cropType,
                'landSize': landSize,
                'landSizeDetails': landSizeDetails,
                'landPhotos': landPhotos, // Land photos from lands collection
                'province': province,
                'district': district,
                'village': village,
                'gnDivision': gnDivision,
                'agDivision': agDivision,
                'country': country,
                'teaLandSize': teaLandSize,
                'cinnamonLandSize': cinnamonLandSize,
                'landSizeUnit': landSizeUnit,
                'hasLandDetails': landDetails != null,
                'landId': landDetails?['landId'] ?? locDoc.id,
              });
            }
          } catch (e) {
            debugPrint("Error processing land document ${locDoc.id}: $e");
            continue;
          }
        }
      }

      if (allLocations.isNotEmpty) {
        final avgLat = allLocations.map((l) => l['latitude'] as double).reduce((a, b) => a + b) / allLocations.length;
        final avgLng = allLocations.map((l) => l['longitude'] as double).reduce((a, b) => a + b) / allLocations.length;
        _centerLocation = LatLng(avgLat, avgLng);
      } else {
        _centerLocation = const LatLng(7.8731, 80.7718);
      }

      setState(() {
        _landLocations = allLocations;
        _filteredLandLocations = List.from(allLocations);
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error fetching land locations: $e");
      setState(() {
        _errorMessage = "Failed to load land locations";
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_landLocations);

    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((land) {
        final displayName = land['displayName']?.toString().toLowerCase() ?? '';
        final landName = land['landName']?.toString().toLowerCase() ?? '';
        final ownerName = land['ownerName']?.toString().toLowerCase() ?? '';
        final address = land['address']?.toString().toLowerCase() ?? '';
        final cropType = land['cropType']?.toString().toLowerCase() ?? '';
        final village = land['village']?.toString().toLowerCase() ?? '';
        final district = land['district']?.toString().toLowerCase() ?? '';
        final province = land['province']?.toString().toLowerCase() ?? '';
        
        return displayName.contains(searchLower) ||
               landName.contains(searchLower) ||
               ownerName.contains(searchLower) ||
               address.contains(searchLower) ||
               cropType.contains(searchLower) ||
               village.contains(searchLower) ||
               district.contains(searchLower) ||
               province.contains(searchLower);
      }).toList();
    }

    if (_selectedProvince != null && _selectedProvince != 'All Provinces') {
      final provinceLower = _selectedProvince!.toLowerCase();
      filtered = filtered.where((land) {
        final province = land['province']?.toString().toLowerCase() ?? '';
        final address = land['address']?.toString().toLowerCase() ?? '';
        return province.contains(provinceLower) || 
               address.contains(provinceLower) || 
               _checkProvinceMatch(provinceLower, address);
      }).toList();
    }

    setState(() {
      _filteredLandLocations = filtered;
    });
  }

  bool _checkProvinceMatch(String province, String address) {
    final provinceMap = {
      'western': ['colombo', 'gampaha', 'kalutara'],
      'central': ['kandy', 'matale', 'nuwara eliya'],
      'southern': ['galle', 'matara', 'hambantota'],
      'eastern': ['ampara', 'batticaloa', 'trincomalee'],
      'northern': ['jaffna', 'kilinochchi', 'mannar', 'mullaitivu', 'vavuniya'],
      'north western': ['kurunegala', 'puttalam'],
      'north central': ['anuradhapura', 'polonnaruwa'],
      'uva': ['badulla', 'monaragala'],
      'sabaragamuwa': ['ratnapura', 'kegalle'],
    };
    
    for (final entry in provinceMap.entries) {
      if (province.contains(entry.key)) {
        return entry.value.any((districtName) => address.contains(districtName));
      }
    }
    return false;
  }

  void _clearFilters() {
    setState(() {
      _selectedProvince = null;
      _searchController.clear();
      _showFilters = false;
      _filteredLandLocations = List.from(_landLocations);
    });
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  // 🌟 NEW: Show land photos
  void _showLandPhotos(List<String> photos) {
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No photos available for this land'),
          backgroundColor: AppColors.warningOrange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _currentLandPhotos = photos;
      _currentPhotoIndex = 0;
      _showPhotoViewer = true;
    });
  }

  // 🌟 NEW: Land photos viewer widget
  Widget _buildPhotoViewer() {
    if (!_showPhotoViewer || _currentLandPhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(_screenWidth < 360 ? 10 : 20),
      child: Container(
        height: _screenHeight * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Land Photos (${_currentPhotoIndex + 1}/${_currentLandPhotos.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _showPhotoViewer = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Photo display
            Expanded(
              child: PageView.builder(
                itemCount: _currentLandPhotos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(_currentLandPhotos[index]),
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Photo indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_currentLandPhotos.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPhotoIndex == index 
                          ? AppColors.primaryBlue 
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
            ),
            
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentPhotoIndex > 0
                        ? () {
                            setState(() {
                              _currentPhotoIndex--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _currentPhotoIndex < _currentLandPhotos.length - 1
                        ? () {
                            setState(() {
                              _currentPhotoIndex++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
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

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 24),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
                    ? const Icon(Icons.person, size: 32, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName, 
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _factoryName, 
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.headerTextDark.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _userRole, 
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.headerTextDark.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16), 
          
          Text(
            'Land Locations',
            style: const TextStyle(
              fontSize: 18,
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
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(
        horizontal: _screenWidth > 400 ? 16 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primaryBlue, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: const InputDecoration(
                      hintText: 'Search lands...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: _screenWidth > 400 ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          if (_showFilters) ...[
            const SizedBox(height: 10),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Province',
                  style: TextStyle(
                    fontSize: _screenWidth > 400 ? 14 : 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProvince,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 14,
                      ),
                      items: _provinces.map((province) {
                        return DropdownMenuItem(
                          value: province,
                          child: Text(
                            province,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProvince = value;
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 14),
                  label: Text(
                    'Clear Filters',
                    style: TextStyle(
                      fontSize: _screenWidth > 400 ? 13 : 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
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
    final mapHeight = _isPortrait 
        ? (_screenHeight * 0.35)
        : (_screenHeight * 0.65);
    
    return Container(
      height: mapHeight,
      margin: EdgeInsets.symmetric(
        horizontal: _screenWidth > 400 ? 16 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _centerLocation ?? const LatLng(7.8731, 80.7718),
            zoom: _zoomLevel,
            onTap: (position, latLng) {
              setState(() {
                _selectedLocation = null;
                _selectedLand = null;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _tileLayers[_selectedTileLayer]['url'],
              userAgentPackageName: 'com.example.land_locations',
            ),
            
            MarkerLayer(
              markers: _filteredLandLocations.map((land) {
                final latLng = LatLng(land['latitude'] as double, land['longitude'] as double);
                final isSelected = _selectedLand != null && _selectedLand!['id'] == land['id'];
                
                return Marker(
                  point: latLng,
                  width: isSelected ? 40 : 30,
                  height: isSelected ? 40 : 30,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLocation = latLng;
                        _selectedLand = land;
                      });
                      _mapController.move(latLng, _zoomLevel);
                    },
                    child: Icon(
                      Icons.agriculture,
                      color: isSelected ? AppColors.warningOrange : AppColors.successGreen,
                      size: isSelected ? 32 : 24,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation!,
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.accentRed,
                      size: 32,
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

  Widget _buildLandList() {
    if (_filteredLandLocations.isEmpty) {
      return Container();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _screenWidth > 400 ? 16 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lands (${_filteredLandLocations.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              if (!_isPortrait)
                IconButton(
                  icon: Icon(
                    _showListInLandscape ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: AppColors.primaryBlue,
                  ),
                  onPressed: () {
                    setState(() {
                      _showListInLandscape = !_showListInLandscape;
                    });
                  },
                ),
            ],
          ),
        ),
        
        if (_isPortrait || _showListInLandscape)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: _screenWidth > 400 ? 16 : 12,
            ),
            itemCount: _filteredLandLocations.length,
            itemBuilder: (context, index) {
              return _buildLandCard(_filteredLandLocations[index]);
            },
          ),
      ],
    );
  }

  Widget _buildLandCard(Map<String, dynamic> land) {
    final isSelected = _selectedLand != null && _selectedLand!['id'] == land['id'];
    final displayName = land['displayName'] ?? land['landName'] ?? 'Unnamed Land';
    final cropType = land['cropType'] ?? 'N/A';
    final isSmallScreen = _screenWidth < 360;
    final landPhotos = land['landPhotos'] as List<String>? ?? [];
    final hasPhotos = landPhotos.isNotEmpty;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLand = land;
          _selectedLocation = LatLng(land['latitude'] as double, land['longitude'] as double);
        });
        _mapController.move(_selectedLocation!, _zoomLevel);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.successGreen.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.successGreen : Colors.grey.withOpacity(0.15),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Crop type icon
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _getCropColor(cropType).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    _getCropIcon(cropType),
                    color: _getCropColor(cropType),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Land name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 3),
                    
                    // Owner name
                    Text(
                      'Owner: ${land['ownerName'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Details row
                    Row(
                      children: [
                        Icon(Icons.square_foot, size: 11, color: AppColors.successGreen),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            'Size: ${land['landSize']} ${land['landSizeUnit'] ?? 'Ac'}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              color: AppColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on, size: 11, color: AppColors.primaryBlue),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _getShortAddress(land),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              color: AppColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Photo indicator and Crop type badge
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          // Photos button if available
                          if (hasPhotos)
                            GestureDetector(
                              onTap: () => _showLandPhotos(landPhotos),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primaryBlue.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo,
                                      size: 10,
                                      color: AppColors.primaryBlue,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${landPhotos.length} photos',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Crop type badge
                          if (cropType != 'N/A')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getCropColor(cropType).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                cropType,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getCropColor(cropType),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Selected indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSelectedLandDetails() {
    if (_selectedLand == null) return const SizedBox.shrink();
    
    final cropType = _selectedLand!['cropType'] ?? 'N/A';
    final isSmallScreen = _screenWidth < 360;
    final landPhotos = _selectedLand!['landPhotos'] as List<String>? ?? [];
    final hasPhotos = landPhotos.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(
        horizontal: _screenWidth > 400 ? 16 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Land Details',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedLand = null;
                    _selectedLocation = null;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Land name and crop type
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getCropColor(cropType).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getCropColor(cropType).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getCropColor(cropType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getCropIcon(cropType),
                      color: _getCropColor(cropType),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedLand!['landName'] ?? _selectedLand!['displayName'] ?? 'Unnamed Land',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cropType != 'N/A')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCropColor(cropType).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCropIcon(cropType),
                                  size: 12,
                                  color: _getCropColor(cropType),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  cropType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getCropColor(cropType),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 🌟 NEW: Land photos preview
          if (hasPhotos) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_library, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Land Photos (${landPhotos.length})',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: landPhotos.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _showLandPhotos(landPhotos),
                        child: Container(
                          width: 100,
                          height: 80,
                          margin: EdgeInsets.only(right: index < landPhotos.length - 1 ? 8 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            //border: Border.all(color: AppColors.borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              landPhotos[index],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: AppColors.primaryBlue,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showLandPhotos(landPhotos),
                    icon: const Icon(Icons.open_in_full, size: 14),
                    label: Text(
                      'View All Photos',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Details list
          ..._buildDetailRows(),
          
          // Google Maps button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final lat = _selectedLand!['latitudeString'];
                final lng = _selectedLand!['longitudeString'];
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
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailRows() {
    final isSmallScreen = _screenWidth < 360;
    final List<Widget> rows = [];
    final fields = [
      {'label': 'Owner Name', 'value': _selectedLand!['ownerName'] ?? 'N/A'},
      if (_selectedLand!['contactNumber'] != null && _selectedLand!['contactNumber'] != 'N/A')
        {'label': 'Contact', 'value': _selectedLand!['contactNumber']},
      {'label': 'Coordinates', 'value': '${_selectedLand!['latitudeString']}, ${_selectedLand!['longitudeString']}'},
    ];
    
    if (_selectedLand!['hasLandDetails'] == true) {
      final additionalFields = [
        {'label': 'Land Size', 'value': '${_selectedLand!['landSize']} ${_selectedLand!['landSizeUnit'] ?? 'Hectares'}'},
        if (_selectedLand!['teaLandSize'] != null && _selectedLand!['teaLandSize'] != 'N/A')
          {'label': 'Tea Land Size', 'value': '${_selectedLand!['teaLandSize']} Ac'},
        if (_selectedLand!['cinnamonLandSize'] != null && _selectedLand!['cinnamonLandSize'] != 'N/A')
          {'label': 'Cinnamon Land Size', 'value': '${_selectedLand!['cinnamonLandSize']} Ac'},
        if (_selectedLand!['province'] != null && _selectedLand!['province'] != 'N/A')
          {'label': 'Province', 'value': _selectedLand!['province']},
        if (_selectedLand!['district'] != null && _selectedLand!['district'] != 'N/A')
          {'label': 'District', 'value': _selectedLand!['district']},
        if (_selectedLand!['village'] != null && _selectedLand!['village'] != 'N/A')
          {'label': 'Village', 'value': _selectedLand!['village']},
        if (_selectedLand!['address'] != null && _selectedLand!['address'] != 'Address not available')
          {'label': 'Address', 'value': _selectedLand!['address']},
      ];
      
      fields.insertAll(2, additionalFields);
    } else {
      fields.insert(2, {'label': 'Address', 'value': _selectedLand!['address'] ?? 'N/A'});
    }
    
    for (var field in fields) {
      rows.addAll([
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: isSmallScreen ? 80 : 90,
              child: Text(
                '${field['label']}:',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                field['value'] ?? '',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 13,
                  color: AppColors.darkText,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ]);
    }
    
    return rows;
  }

  String _getShortAddress(Map<String, dynamic> land) {
    if (land['village'] != null && land['village'] != 'N/A') {
      final village = land['village'];
      return village.length > 15 ? '${village.substring(0, 15)}...' : village;
    } else if (land['district'] != null && land['district'] != 'N/A') {
      final district = land['district'];
      return district.length > 15 ? '${district.substring(0, 15)}...' : district;
    } else if (land['address'] != null && land['address'] != 'Address not available') {
      final address = land['address'];
      if (address.length > 20) {
        return '${address.substring(0, 20)}...';
      }
      return address;
    }
    return 'Location';
  }

  Color _getCropColor(String? cropType) {
    switch (cropType?.toLowerCase()) {
      case 'tea':
        return AppColors.successGreen;
      case 'cinnamon':
        return AppColors.warningOrange;
      case 'both':
        return AppColors.accentTeal;
      case 'paddy':
        return const Color(0xFF8BC34A);
      case 'vegetables':
        return AppColors.primaryBlue;
      case 'fruits':
        return AppColors.accentRed;
      default:
        return AppColors.secondaryText;
    }
  }

  IconData _getCropIcon(String? cropType) {
    switch (cropType?.toLowerCase()) {
      case 'tea':
        return Icons.emoji_nature;
      case 'cinnamon':
        return Icons.spa;
      case 'both':
        return Icons.all_inclusive;
      case 'paddy':
        return Icons.grass;
      case 'vegetables':
        return Icons.eco;
      case 'fruits':
        return Icons.apple;
      default:
        return Icons.terrain;
    }
  }

  Widget _buildEmptyState() {
    final isSmallScreen = _screenWidth < 360;
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchController.text.isNotEmpty || _selectedProvince != null
              ? Icons.search_off
              : Icons.agriculture,
            size: isSmallScreen ? 48 : 56,
            color: AppColors.successGreen,
          ),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty || _selectedProvince != null
              ? 'No Matching Lands'
              : 'No Land Locations',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty || _selectedProvince != null
              ? 'Try adjusting your search or filters'
              : 'No land locations found in database',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 12 : 13,
            ),
          ),
          if (_searchController.text.isNotEmpty || _selectedProvince != null)
            const SizedBox(height: 12),
          if (_searchController.text.isNotEmpty || _selectedProvince != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 14),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isSmallScreen = _screenWidth < 360;
    
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: isSmallScreen ? 40 : 48,
            color: AppColors.accentRed,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchLandLocations,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.successGreen),
          const SizedBox(height: 12),
          const Text(
            'Loading land locations...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildFilterSection(),
              _buildMapSection(),
              if (_selectedLand != null)
                _buildSelectedLandDetails(),
              if (_isLoading)
                _buildLoadingState()
              else if (_errorMessage != null)
                _buildErrorState()
              else if (_filteredLandLocations.isEmpty)
                _buildEmptyState()
              else
                _buildLandList(),
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Developed by Malitha Tishamal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkText.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 🌟 Photo viewer overlay
        if (_showPhotoViewer)
          _buildPhotoViewer(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildMapSection(),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildFilterSection(),
                          if (_selectedLand != null)
                            _buildSelectedLandDetails(),
                          if (_isLoading)
                            _buildLoadingState()
                          else if (_errorMessage != null)
                            _buildErrorState()
                          else if (_filteredLandLocations.isEmpty)
                            _buildEmptyState()
                          else
                            _buildLandList(),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Developed by Malitha Tishamal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // 🌟 Photo viewer overlay
        if (_showPhotoViewer)
          _buildPhotoViewer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    
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
          // Header (Fixed)
          _buildDashboardHeader(context),
          
          // Main Content (Scrollable)
          Expanded(
            child: _isPortrait 
                ? _buildMainContent()
                : _buildLandscapeLayout(),
          ),
        ],
      ),
    );
  }
}