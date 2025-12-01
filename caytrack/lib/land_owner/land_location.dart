import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'land_owner_drawer.dart'; // Make sure to import your drawer

class LocationSelectionPage extends StatefulWidget {
  final Function(Map<String, dynamic>) onLocationSelected;
  final Map<String, dynamic>? existingData;

  const LocationSelectionPage({
    super.key,
    required this.onLocationSelected,
    this.existingData,
  });

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  late MapController _mapController;
  LatLng? _currentLocation;
  LatLng? _selectedLocation;
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  String _address = '';
  String _latitude = '';
  String _longitude = '';
  
  double _zoomLevel = 15.0;

  String _selectedLocationType = 'auto';

  final TextEditingController _manualLatController = TextEditingController();
  final TextEditingController _manualLngController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final List<Map<String, String>> _tileLayers = [
    {
      'name': 'OpenStreetMap Standard',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors'
    },
  ];

  int _selectedTileLayer = 0;
  Map<String, dynamic>? _fetchedExistingData;

  // Header variables
  String _loggedInUserName = 'Loading...';
  String _landName = 'Loading...';
  String _userRole = 'Land Owner';
  String _landID = 'L-ID';
  String? _profileImageUrl;

  // Custom colors matching LandOwnerDashboard
  static const Color _headerGradientStart = Color(0xFF869AEC);
  static const Color _headerGradientEnd = Color(0xFFF7FAFF);
  static const Color _headerTextDark = Color(0xFF333333);
  static const Color _primaryBlue = Color(0xFF2764E7);
  static const Color _accentRed = Color(0xFFE53935);
  static const Color _accentTeal = Color(0xFF00BFA5);
  static const Color _secondaryColor = Color(0xFF6AD96A);

  // Scaffold key for drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _initializeFormData();
    _fetchExistingLocation();
    _getCurrentLocation();
    _fetchHeaderData(); // Fetch header data
  }

  // Drawer navigation handler
  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context); // Close drawer
    
    // Handle navigation based on route name
    if (routeName == 'dashboard') {
      Navigator.pop(context); // Go back to dashboard
    } else if (routeName == 'profile') {
      // Navigate to profile page
      // Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
    } else if (routeName == 'logout') {
      _handleLogout();
    }
    // Add more routes as needed
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
      // Navigate to login screen
      // Navigator.pushAndRemoveUntil(
      //   context,
      //   MaterialPageRoute(builder: (context) => LoginPage()),
      //   (route) => false,
      // );
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Fetch header data similar to LandOwnerDashboard
  void _fetchHeaderData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;
    setState(() {
      _landID = uid.length >= 8 ? uid.substring(0, 8) : uid.padRight(8, '0'); 
    });

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
      // 2. Fetch Land Name from 'lands' collection
      final landDoc = await FirebaseFirestore.instance.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name Missing';
        });
      }

    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _landName = 'Data Error';
      });
    }
  }

  void _initializeFormData() {
    if (widget.existingData != null) {
      _populateFieldsFromData(widget.existingData!);
    }
  }
  
  Future<void> _fetchExistingLocation() async {
    final User? user = _auth.currentUser;
    if (user == null || widget.existingData != null) {
      return;
    }
    
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final docSnapshot = await _firestore.collection('land_location').doc(user.uid).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _fetchedExistingData = data;
        
        _populateFieldsFromData(data);
        
        // Force UI update with static data from Firebase
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching existing location: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _populateFieldsFromData(Map<String, dynamic> data) {
    if (data['latitude'] != null && data['longitude'] != null) {
      final lat = data['latitude'] is String 
          ? double.tryParse(data['latitude']) ?? 0.0
          : data['latitude'] as double;
      final lng = data['longitude'] is String 
          ? double.tryParse(data['longitude']) ?? 0.0
          : data['longitude'] as double;
      
      _selectedLocation = LatLng(lat, lng);
      // Fixed: Use latitudeString/longitudeString from Firebase for static display
      _latitude = data['latitudeString'] ?? lat.toStringAsFixed(6);
      _longitude = data['longitudeString'] ?? lng.toStringAsFixed(6);
      
      _address = data['address'] ?? 'Address not available';
      _selectedLocationType = data['locationType'] ?? 'manual';
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedLocation != null) {
        _mapController.move(_selectedLocation!, _zoomLevel);
      }
    });
  }

  @override
  void dispose() {
    _manualLatController.dispose();
    _manualLngController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _handleLocationFailure('Location Service Disabled', 'Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _handleLocationFailure('Location Permission Required', 'This app needs location permission.');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 15));
      
      if (mounted) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        
        if (_selectedLocation == null) {
          _selectedLocation = _currentLocation;
          _selectedLocationType = 'auto';
          await _getAddressFromLatLng(_currentLocation!);
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(_selectedLocation!, _zoomLevel);
            }
          });
        }
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Location error: $e');
      _handleLocationFailure('Location Error', 'Failed to get current location.');
    }
  }

  void _handleLocationFailure(String title, String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _selectedLocationType = 'manual';
        _currentLocation = const LatLng(6.9271, 79.8612);
        _selectedLocation = _selectedLocation ?? _currentLocation;
      });
      if (title.contains('Disabled') || title.contains('Required')) {
        _showErrorDialog(title, message);
      }
    }
  }
  
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        if (mounted) {
          setState(() {
            _address = address.isNotEmpty ? address : 'Address not available';
            _latitude = latLng.latitude.toStringAsFixed(6);
            _longitude = latLng.longitude.toStringAsFixed(6);
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _address = 'Address not found for coordinates';
            _latitude = latLng.latitude.toStringAsFixed(6);
            _longitude = latLng.longitude.toStringAsFixed(6);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lng: ${latLng.longitude.toStringAsFixed(6)}';
          _latitude = latLng.latitude.toStringAsFixed(6);
          _longitude = latLng.longitude.toStringAsFixed(6);
        });
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = latLng;
      _selectedLocationType = 'manual';
    });
    _getAddressFromLatLng(latLng);
  }

  void _goToCurrentLocation() async {
    if (!mounted) return;
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _zoomLevel);
      setState(() {
        _selectedLocation = _currentLocation;
        _selectedLocationType = 'auto';
      });
      _getAddressFromLatLng(_currentLocation!);
    } else {
      await _getCurrentLocation();
    }
  }

  void _useManualCoordinates() {
    if (!mounted) return;
    try {
      final lat = double.tryParse(_manualLatController.text);
      final lng = double.tryParse(_manualLngController.text);
      
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        final newLocation = LatLng(lat, lng);
        setState(() {
          _selectedLocation = newLocation;
          _selectedLocationType = 'manual';
        });
        _getAddressFromLatLng(newLocation);
        _mapController.move(newLocation, _zoomLevel);
        
        _manualLatController.clear();
        _manualLngController.clear();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location updated using manual coordinates!'),
            backgroundColor: _primaryBlue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter valid coordinates (-90 to 90 for Lat, -180 to 180 for Lng)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Manual coordinates error: $e');
    }
  }

  Future<void> _searchLocation() async {
    if (!mounted || _searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(_searchController.text)}&limit=1',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isNotEmpty) {
          final result = results.first;
          final newLocation = LatLng(double.parse(result['lat']), double.parse(result['lon']));
          
          if (mounted) {
            setState(() {
              _selectedLocation = newLocation;
              _selectedLocationType = 'manual';
            });
            _getAddressFromLatLng(newLocation);
            _mapController.move(newLocation, _zoomLevel);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Found: ${result['display_name']}'),
                backgroundColor: _primaryBlue,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToFirebase() async {
    if (!mounted || _selectedLocation == null) return;
    
    setState(() {
      _isSaving = true;
    });

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to save data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final String documentId = user.uid;
      final DocumentReference landLocationDocRef = 
          _firestore.collection('land_location').doc(documentId);
      
      bool isUpdate = _fetchedExistingData != null || widget.existingData != null;

      final locationData = {
        'userId': user.uid,
        'address': _address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'latitudeString': _latitude,
        'longitudeString': _longitude,
        'locationType': _selectedLocationType,
        'createdAt': (widget.existingData?['createdAt'] ?? _fetchedExistingData?['createdAt']) 
                     ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await landLocationDocRef.set(locationData);

      final String successMessage = isUpdate 
          ? 'Location updated successfully!'
          : 'Location saved successfully!';

      locationData['docId'] = documentId;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: _primaryBlue,
            ),
          );
          widget.onLocationSelected(locationData);
          Navigator.pop(context);
        }
      });

    } catch (e) {
      print('Firebase save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Fixed: Proper static data display from Firebase
  // Fixed: Proper static data display from Firebase
Widget _buildExistingLocationDisplay() {
  final User? user = _auth.currentUser;
  if (user == null) return const SizedBox.shrink();
  
  final Map<String, dynamic>? savedData = _fetchedExistingData ?? widget.existingData;
  
  if (savedData == null || savedData.isEmpty) {
    return const SizedBox.shrink();
  }

  // Fixed: Use the stored string values directly for static display
  final displayLat = savedData['latitudeString'] ?? savedData['latitude']?.toStringAsFixed(6) ?? '--';
  final displayLng = savedData['longitudeString'] ?? savedData['longitude']?.toStringAsFixed(6) ?? '--';
  final displayAddress = savedData['address'] ?? 'Address not available';
  
  double? savedLat;
  double? savedLng;
  
  try {
    savedLat = (savedData['latitude'] as num?)?.toDouble();
    savedLng = (savedData['longitude'] as num?)?.toDouble();
  } catch (e) {
    print('Error parsing saved coordinates: $e');
  }

  final openMapUrl = 'https://www.google.com/maps/search/?api=1&query=$displayLat,$displayLng';

  return Card(
    // CHANGED: Background color to light grey
    color: Colors.grey[100], // Changed from _primaryBlue.withOpacity(0.05) to grey[100]
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      // CHANGED: Border color to grey
      side: BorderSide(color: Colors.grey[300]!, width: 1), // Changed from _primaryBlue.withOpacity(0.2)
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_history,
                // CHANGED: Icon color to grey
                color: Colors.grey[700], // Changed from _primaryBlue to grey[700]
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Previously Saved Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  // CHANGED: Text color to grey
                  color: Colors.grey[800], // Changed from _primaryBlue to grey[800]
                ),
              ),
            ],
          ),
          // CHANGED: Divider color to light grey
          const Divider(color: Color(0xFFE0E0E0)), // Changed from Color.fromARGB(255, 234, 186, 186)
          _buildDetailRow('Saved Address', displayAddress),
          _buildDetailRow('Latitude', displayLat),
          _buildDetailRow('Longitude', displayLng),
          _buildDetailRow('Updated At', 
              (savedData['updatedAt'] is Timestamp) 
                  ? (savedData['updatedAt'] as Timestamp).toDate().toString().split('.')[0] 
                  : 'N/A'),
          
          const SizedBox(height: 12),
          
          if (savedLat != null && savedLng != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _mapController.move(LatLng(savedLat!, savedLng!), _zoomLevel);
                    },
                    // CHANGED: Button icon and text color to grey
                    icon: Icon(Icons.travel_explore, size: 18, color: Colors.grey[700]),
                    label: Text('View on Map', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    style: ElevatedButton.styleFrom(
                      // CHANGED: Button background to light grey
                      backgroundColor: Colors.grey[200], // Changed from _primaryBlue.withOpacity(0.1)
                      foregroundColor: Colors.grey[700], // Changed from _primaryBlue
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (await canLaunchUrlString(openMapUrl)) {
                        await launchUrlString(openMapUrl);
                      }
                    },
                    icon: Icon(Icons.open_in_new, size: 18, color: Colors.white),
                    label: Text('Open in Maps', style: TextStyle(fontSize: 14, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      // CHANGED: Button background to grey
                      backgroundColor: Colors.grey[600], // Changed from _primaryBlue
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          
          const SizedBox(height: 16),
          
          Text(
            'You can update a new location by selecting a point on the map below.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              // CHANGED: Text color to grey
              color: const Color.fromARGB(255, 113, 121, 212), // Changed from Colors.blueGrey
              fontSize: 13,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLocationTypeSelection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Location Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildLocationTypeCard('Auto Location', 'Use your current location automatically', Icons.my_location, 'auto')),
                const SizedBox(width: 12),
                Expanded(child: _buildLocationTypeCard('Manual Location', 'Select location manually on map or enter coordinates', Icons.edit_location_alt, 'manual')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTypeCard(String title, String description, IconData icon, String type) {
    final bool isSelected = _selectedLocationType == type;
    
    return GestureDetector(
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedLocationType = type;
          if (type == 'auto' && _currentLocation != null) {
            _selectedLocation = _currentLocation;
            _getAddressFromLatLng(_currentLocation!);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.15) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryBlue : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? _primaryBlue : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? _primaryBlue : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualLocationInput() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Coordinates Manually',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualLatController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      labelStyle: TextStyle(color: _primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue, width: 2),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _manualLngController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      labelStyle: TextStyle(color: _primaryBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue, width: 2),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _useManualCoordinates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Go'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Header Widget (same as LandOwnerDashboard)
  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_headerGradientStart, _headerGradientEnd], 
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
            offset: Offset(0, 5),
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
                icon: const Icon(Icons.menu, color: _headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              
             
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Profile Picture
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [_primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryBlue.withOpacity(0.4),
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
              
              // User Info Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Land Name
                  Text(
                    _landName, 
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _headerTextDark,
                    ),
                  ),
                  // 2. Logged-in User Name and Role
                  Text(
                    'Logged in as: $_loggedInUserName \n($_userRole)', 
                    style: TextStyle(
                      fontSize: 14,
                      color: _headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25), 
          
          // Page specific title
          Text(
            'Select or Update Land Location',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _headerTextDark,
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
      backgroundColor: Colors.grey[50],
      // Add drawer here
      drawer: LandOwnerDrawer(
        onLogout: () {
          _handleLogout();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header from LandOwnerDashboard
                _buildDashboardHeader(context),
                
                // Content area with footer
                Expanded(
                  child: Column(
                    children: [
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Existing Location Card (STATIC DATA FROM FIREBASE)
                              _buildExistingLocationDisplay(),
                              
                              const SizedBox(height: 16),
                              
                              // 2. Location Type Selection
                              _buildLocationTypeSelection(),
                              
                              const SizedBox(height: 16),
                              
                              // 3. Manual Coordinates Input
                              if (_selectedLocationType == 'manual') ...[
                                _buildManualLocationInput(),
                                const SizedBox(height: 16),
                              ],
                              
                              // 4. Map
                              Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Map',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _primaryBlue,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                onPressed: _goToCurrentLocation,
                                                icon: Icon(Icons.my_location, color: _primaryBlue),
                                                tooltip: 'Go to current location',
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  if (_selectedLocation != null) {
                                                    _mapController.move(_selectedLocation!, _zoomLevel);
                                                  }
                                                },
                                                icon: Icon(Icons.center_focus_strong, color: _primaryBlue),
                                                tooltip: 'Center on selected location',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        height: 400,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            center: _selectedLocation ?? const LatLng(6.9271, 79.8612),
                                            zoom: _zoomLevel,
                                            onTap: _onMapTap,
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: _tileLayers[_selectedTileLayer]['url'],
                                              userAgentPackageName: 'com.example.location_selector',
                                            ),
                                            MarkerLayer(
                                              markers: _selectedLocation != null
                                                  ? [
                                                      Marker(
                                                        point: _selectedLocation!,
                                                        width: 40,
                                                        height: 40,
                                                        child: Icon(
                                                          Icons.location_pin,
                                                          color: _selectedLocationType == 'auto' 
                                                              ? _secondaryColor 
                                                              : _primaryBlue,
                                                          size: 40,
                                                        ),
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            RichAttributionWidget(
                                              attributions: [
                                                TextSourceAttribution(
                                                  'OpenStreetMap contributors',
                                                  onTap: () => launchUrlString('https://openstreetmap.org/copyright'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 5. Location Details (CURRENT SELECTION - NOT STATIC)
                              Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Selection (Changes on Map Tap)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDetailRow('Location Type', _selectedLocationType == 'auto' ? 'Auto-detected' : 'Manual'),
                                      _buildDetailRow('Address', _address.isNotEmpty ? _address : 'Not selected'),
                                      _buildDetailRow('Latitude', _latitude.isNotEmpty ? _latitude : '--'),
                                      _buildDetailRow('Longitude', _longitude.isNotEmpty ? _longitude : '--'),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 6. Save Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveToFirebase,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          (widget.existingData != null || _fetchedExistingData != null)
                                              ? 'Update Location'
                                              : 'Save Location',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      
                      // Footer (Fixed at bottom of content area)
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Developed By Malitha Tishamal',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _headerTextDark.withOpacity(0.7),
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

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _primaryBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ));
  }
  
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(color: _primaryBlue),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: _primaryBlue),
            ),
          ),
        ],
      ),
    );
  }
}