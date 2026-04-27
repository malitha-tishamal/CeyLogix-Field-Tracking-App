import 'dart:async';
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
import 'package:vibration/vibration.dart';
import 'land_owner_drawer.dart';

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

  // Custom colors
  static const Color _headerGradientStart = Color(0xFF869AEC);
  static const Color _headerGradientEnd = Color(0xFFF7FAFF);
  static const Color _headerTextDark = Color(0xFF333333);
  static const Color _primaryBlue = Color(0xFF2764E7);
  static const Color _accentRed = Color(0xFFE53935);
  static const Color _accentTeal = Color(0xFF00BFA5);
  static const Color _secondaryColor = Color(0xFF6AD96A);
  static const Color _backgroundColor = Color(0xFFEEEBFF);

  // Scaffold key for drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Responsive variables
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;

  // Real-time tracking variables
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<LatLng> _locationHistory = [];
  Position? _lastPosition;
  DateTime? _lastVibrationTime;
  double _totalDistance = 0.0;
  int _locationUpdateCount = 0;

  // Address cache to avoid repeated API calls
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _initializeFormData();
    _fetchExistingLocation();
    _getCurrentLocation();
    _fetchHeaderData();
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

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  void _handleLogout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
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
    _stopRealtimeTracking();
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
      // Update coordinates immediately
      if (mounted) {
        setState(() {
          _latitude = latLng.latitude.toStringAsFixed(6);
          _longitude = latLng.longitude.toStringAsFixed(6);
        });
      }
      
      // Check cache first
      final cacheKey = '${latLng.latitude.toStringAsFixed(6)}_${latLng.longitude.toStringAsFixed(6)}';
      if (_addressCache.containsKey(cacheKey)) {
        if (mounted) {
          setState(() {
            _address = _addressCache[cacheKey]!;
          });
        }
        return;
      }
      
      // Try to get address from coordinates using better reverse geocoding
      String address = '';
      
      // Method 1: Try using geocoding package first
      try {
        final placemarks = await placemarkFromCoordinates(
          latLng.latitude,
          latLng.longitude,
        ).timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final parts = [
            placemark.street,
            placemark.subLocality,
            placemark.locality,
            placemark.subAdministrativeArea,
            placemark.administrativeArea,
            placemark.country
          ].where((part) => part != null && part.isNotEmpty).toList();
          
          if (parts.isNotEmpty) {
            address = parts.join(', ');
          }
        }
      } catch (e) {
        print('Geocoding package error: $e');
      }
      
      // Method 2: If geocoding package fails, try OpenStreetMap Nominatim API
      if (address.isEmpty || address.contains('null')) {
        try {
          address = await _getAddressFromNominatim(latLng);
        } catch (e) {
          print('Nominatim API error: $e');
        }
      }
      
      // Method 3: If both methods fail, show coordinates
      if (address.isEmpty) {
        address = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lng: ${latLng.longitude.toStringAsFixed(6)}';
      }
      
      // Cache the address
      _addressCache[cacheKey] = address;
      
      if (_addressCache.length > 50) {
        // Remove oldest entry if cache gets too large
        final firstKey = _addressCache.keys.first;
        _addressCache.remove(firstKey);
      }
      
      if (mounted) {
        setState(() {
          _address = address;
        });
      }
      
    } catch (e) {
      print('Address fetching error: $e');
      if (mounted) {
        setState(() {
          _address = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lng: ${latLng.longitude.toStringAsFixed(6)}';
        });
      }
    }
  }
  
  Future<String> _getAddressFromNominatim(LatLng latLng) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1'
        ),
        headers: {
          'User-Agent': 'LocationSelectorApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['display_name'] != null) {
          return data['display_name'] as String;
        } else if (data['address'] != null) {
          final address = data['address'] as Map<String, dynamic>;
          
          // Build address from components
          final parts = [
            address['road'],
            address['neighbourhood'],
            address['suburb'],
            address['city'],
            address['town'],
            address['village'],
            address['county'],
            address['state'],
            address['country']
          ].where((part) => part != null).toList();
          
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
      }
    } catch (e) {
      print('Nominatim error: $e');
      rethrow;
    }
    
    return '';
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = latLng;
      _selectedLocationType = 'manual';
      _stopRealtimeTracking();
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
          _stopRealtimeTracking();
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
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(_searchController.text)}&limit=1&addressdetails=1',
        ),
        headers: {
          'User-Agent': 'LocationSelectorApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        if (results.isNotEmpty) {
          final result = results.first;
          final newLocation = LatLng(double.parse(result['lat']), double.parse(result['lon']));
          
          if (mounted) {
            setState(() {
              _selectedLocation = newLocation;
              _selectedLocationType = 'manual';
              _stopRealtimeTracking();
            });
            await _getAddressFromLatLng(newLocation);
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

  // ==================== REAL-TIME TRACKING METHODS ====================
  
  Future<void> _startRealtimeTracking() async {
    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('Location Service Disabled', 'Please enable location services for real-time tracking.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          _showErrorDialog('Location Permission Required', 'This app needs location permission for real-time tracking.');
          return;
        }
      }

      // Start tracking
      setState(() {
        _isTracking = true;
        _locationHistory.clear();
        _totalDistance = 0.0;
        _locationUpdateCount = 0;
      });

      // Request high accuracy location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
          timeLimit: null,
        ),
      ).listen((Position position) {
        if (!mounted) return;
        
        final newLocation = LatLng(position.latitude, position.longitude);
        
        setState(() {
          _currentLocation = newLocation;
          _selectedLocation = newLocation;
          _selectedLocationType = 'auto';
          _locationUpdateCount++;
          
          // Add to history
          _locationHistory.add(newLocation);
          if (_locationHistory.length > 100) {
            _locationHistory.removeAt(0);
          }
          
          // Calculate distance moved
          if (_lastPosition != null) {
            final distance = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            _totalDistance += distance;
          }
          _lastPosition = position;
        });

        // Update address and map in real-time
        _getAddressFromLatLng(newLocation);
        _mapController.move(newLocation, _zoomLevel);
        
        // Vibration feedback
        if (_locationUpdateCount % 5 == 0 || 
            (_lastVibrationTime == null || 
             DateTime.now().difference(_lastVibrationTime!).inSeconds > 30)) {
          _vibratePhone();
          _lastVibrationTime = DateTime.now();
        }

        // Show notification for significant movement
        if (_totalDistance > 100 && _locationUpdateCount % 10 == 0) {
          _showTrackingNotification();
        }
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Real-time tracking started! Phone will vibrate on updates.'),
          backgroundColor: _secondaryColor,
          duration: const Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print('Tracking error: $e');
      setState(() {
        _isTracking = false;
      });
      _showErrorDialog('Tracking Error', 'Failed to start real-time tracking: $e');
    }
  }

  void _stopRealtimeTracking() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }
    
    if (mounted) {
      setState(() {
        _isTracking = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tracking stopped. Total distance: ${_totalDistance.toStringAsFixed(2)} meters'),
          backgroundColor: _accentRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _vibratePhone() async {
    if (await Vibration.hasVibrator() ?? false) {
      // Pattern: vibrate for 200ms, pause for 100ms, vibrate for 200ms
      Vibration.vibrate(pattern: [200, 100, 200]);
      
      // Also show a visual feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location updated!\nLat: ${_latitude}, Lng: ${_longitude}'),
            backgroundColor: _primaryBlue.withOpacity(0.8),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
  }

  void _showTrackingNotification() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.track_changes, color: Colors.green),
            SizedBox(width: 10),
            Text('Live Tracking Active'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 Updates: $_locationUpdateCount'),
            Text('📏 Distance: ${_totalDistance.toStringAsFixed(2)} m'),
            Text('📍 Lat: $_latitude'),
            Text('📍 Lng: $_longitude'),
            if (_address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('🏠 Address: $_address'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _stopRealtimeTracking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentRed,
            ),
            child: const Text('Stop Tracking', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingControls() {
    final isSmallScreen = _screenWidth < 360;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Real-time Tracking',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                Switch(
                  value: _isTracking,
                  onChanged: (value) {
                    if (value) {
                      _startRealtimeTracking();
                    } else {
                      _stopRealtimeTracking();
                    }
                  },
                  activeColor: _secondaryColor,
                  activeTrackColor: _secondaryColor.withOpacity(0.5),
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            
            if (_isTracking)
              Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, color: _accentTeal, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Live tracking active - Phone vibrating on updates',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12.0 : 14.0,
                            color: _accentTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildDetailRow('Updates', '$_locationUpdateCount', isSmallScreen),
                  _buildDetailRow('Distance', '${_totalDistance.toStringAsFixed(2)} m', isSmallScreen),
                  _buildDetailRow('History', '${_locationHistory.length} points', isSmallScreen),
                  
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showTrackingNotification();
                      },
                      icon: Icon(Icons.notifications_active, size: 18),
                      label: Text('Show Live Data', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentTeal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.orange, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enable real-time tracking for live updates with vibration',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12.0 : 13.0,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Updates every 5 meters\n• Phone vibrates on location change\n• High accuracy GPS',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11.0 : 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingLocationDisplay() {
    final User? user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    final Map<String, dynamic>? savedData = _fetchedExistingData ?? widget.existingData;
    
    if (savedData == null || savedData.isEmpty) {
      return const SizedBox.shrink();
    }

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

    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;

    return Card(
      color: Colors.grey[100],
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_history,
                  color: Colors.grey[700],
                  size: isSmallScreen ? 20.0 : 24.0,
                ),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                Expanded(
                  child: Text(
                    'Previously Saved Location',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE0E0E0)),
            _buildDetailRow('Saved Address', displayAddress, isSmallScreen),
            _buildDetailRow('Latitude', displayLat, isSmallScreen),
            _buildDetailRow('Longitude', displayLng, isSmallScreen),
            _buildDetailRow('Updated At', 
                (savedData['updatedAt'] is Timestamp) 
                    ? (savedData['updatedAt'] as Timestamp).toDate().toString().split('.')[0] 
                    : 'N/A',
                isSmallScreen),
            
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            
            if (savedLat != null && savedLng != null)
              Column(
                children: [
                  if (isSmallScreen)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _mapController.move(LatLng(savedLat!, savedLng!), _zoomLevel);
                            },
                            icon: Icon(Icons.travel_explore, size: 16, color: Colors.grey[700]),
                            label: Text('View on Map', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (await canLaunchUrlString(openMapUrl)) {
                                await launchUrlString(openMapUrl);
                              }
                            },
                            icon: Icon(Icons.open_in_new, size: 16, color: Colors.white),
                            label: Text('Open in Maps', style: TextStyle(fontSize: 13, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _mapController.move(LatLng(savedLat!, savedLng!), _zoomLevel);
                            },
                            icon: Icon(Icons.travel_explore, size: isMediumScreen ? 16 : 18, color: Colors.grey[700]),
                            label: Text(
                              'View on Map', 
                              style: TextStyle(
                                fontSize: isMediumScreen ? 13 : 14, 
                                color: Colors.grey[700]
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (await canLaunchUrlString(openMapUrl)) {
                                await launchUrlString(openMapUrl);
                              }
                            },
                            icon: Icon(Icons.open_in_new, size: isMediumScreen ? 16 : 18, color: Colors.white),
                            label: Text(
                              'Open in Maps', 
                              style: TextStyle(
                                fontSize: isMediumScreen ? 13 : 14, 
                                color: Colors.white
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            
            Text(
              'You can update a new location by selecting a point on the map below.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: const Color.fromARGB(255, 113, 121, 212),
                fontSize: isSmallScreen ? 12.0 : 13.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTypeSelection() {
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Location Method',
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            if (isSmallScreen)
              Column(
                children: [
                  _buildLocationTypeCard(
                    'Auto Location', 
                    'Use current location', 
                    Icons.my_location, 
                    'auto',
                    isSmallScreen,
                    isMediumScreen
                  ),
                  SizedBox(height: 8),
                  _buildLocationTypeCard(
                    'Manual Location', 
                    'Select on map or enter coordinates', 
                    Icons.edit_location_alt, 
                    'manual',
                    isSmallScreen,
                    isMediumScreen
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildLocationTypeCard(
                      'Auto Location', 
                      'Use your current location automatically', 
                      Icons.my_location, 
                      'auto',
                      isSmallScreen,
                      isMediumScreen
                    ),
                  ),
                  SizedBox(width: isMediumScreen ? 8.0 : 12.0),
                  Expanded(
                    child: _buildLocationTypeCard(
                      'Manual Location', 
                      'Select location manually on map or enter coordinates', 
                      Icons.edit_location_alt, 
                      'manual',
                      isSmallScreen,
                      isMediumScreen
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTypeCard(String title, String description, IconData icon, String type, bool isSmallScreen, bool isMediumScreen) {
    final bool isSelected = _selectedLocationType == type;
    final titleFontSize = isSmallScreen ? 12.0 : isMediumScreen ? 13.0 : 14.0;
    final descFontSize = isSmallScreen ? 10.0 : isMediumScreen ? 11.0 : 12.0;
    final iconSize = isSmallScreen ? 24.0 : isMediumScreen ? 28.0 : 32.0;
    final padding = isSmallScreen ? 12.0 : 16.0;
    
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
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.15) : Colors.grey[50],
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? _primaryBlue : Colors.grey,
              size: iconSize,
            ),
            SizedBox(height: isSmallScreen ? 6.0 : 8.0),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
                color: isSelected ? _primaryBlue : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmallScreen ? 3.0 : 4.0),
            Text(
              description,
              style: TextStyle(
                fontSize: descFontSize,
                color: isSelected ? _primaryBlue : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualLocationInput() {
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Coordinates Manually',
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            if (isSmallScreen)
              Column(
                children: [
                  TextField(
                    controller: _manualLatController,
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      labelStyle: TextStyle(color: _primaryBlue, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, 
                        vertical: isSmallScreen ? 10 : 12
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _manualLngController,
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      labelStyle: TextStyle(color: _primaryBlue, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryBlue),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, 
                        vertical: isSmallScreen ? 10 : 12
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _useManualCoordinates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 16, 
                          vertical: isSmallScreen ? 12 : 15
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Update Location',
                        style: TextStyle(fontSize: isSmallScreen ? 13 : 14),
                      ),
                    ),
                  ),
                ],
              )
            else
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  SizedBox(width: isMediumScreen ? 8.0 : 12.0),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  SizedBox(width: isMediumScreen ? 8.0 : 12.0),
                  ElevatedButton(
                    onPressed: _useManualCoordinates,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMediumScreen ? 16 : 20, 
                        vertical: isMediumScreen ? 14 : 15
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Go',
                      style: TextStyle(fontSize: isMediumScreen ? 14 : 15),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final profileSize = isSmallScreen ? 60.0 : 70.0;
    final menuIconSize = isSmallScreen ? 24.0 : 28.0;
    final nameFontSize = isSmallScreen ? 16.0 : 20.0;
    final landFontSize = isSmallScreen ? 14.0 : 16.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isSmallScreen ? 16.0 : 20.0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_headerGradientStart, _headerGradientEnd],
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
                icon: Icon(Icons.menu, color: _headerTextDark, size: menuIconSize),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: menuIconSize + 16,
                  minHeight: menuIconSize + 16,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8.0 : 10.0),
          
          Row(
            children: [
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [_primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(
                    color: Colors.white, 
                    width: isSmallScreen ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryBlue.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 8.0 : 10.0,
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
                    ? Icon(
                        Icons.person, 
                        size: isSmallScreen ? 32.0 : 40.0, 
                        color: Colors.white
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12.0 : 15.0),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName, 
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: _headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Land Name: $_landName \n($_userRole)', 
                      style: TextStyle(
                        fontSize: landFontSize,
                        color: _headerTextDark.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 20.0 : 25.0), 
          
          Text(
            'Select or Update Land Location',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: _headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard() {
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    final mapHeight = isSmallScreen ? _screenHeight * 0.35 : _screenHeight * 0.4;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interactive Map',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _goToCurrentLocation,
                      icon: Icon(
                        Icons.my_location, 
                        color: _primaryBlue,
                        size: isSmallScreen ? 20.0 : 24.0,
                      ),
                      padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 36.0 : 40.0,
                        minHeight: isSmallScreen ? 36.0 : 40.0,
                      ),
                      tooltip: 'Go to current location',
                    ),
                    IconButton(
                      onPressed: () {
                        if (_selectedLocation != null) {
                          _mapController.move(_selectedLocation!, _zoomLevel);
                        }
                      },
                      icon: Icon(
                        Icons.center_focus_strong, 
                        color: _primaryBlue,
                        size: isSmallScreen ? 20.0 : 24.0,
                      ),
                      padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 36.0 : 40.0,
                        minHeight: isSmallScreen ? 36.0 : 40.0,
                      ),
                      tooltip: 'Center on selected location',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            Container(
              height: mapHeight,
              decoration: BoxDecoration(
                border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
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
                              width: isSmallScreen ? 32.0 : 40.0,
                              height: isSmallScreen ? 32.0 : 40.0,
                              child: Icon(
                                Icons.location_pin,
                                color: _selectedLocationType == 'auto' 
                                    ? _secondaryColor 
                                    : _primaryBlue,
                                size: isSmallScreen ? 32.0 : 40.0,
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
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            Text(
              'Tap anywhere on the map to select a location',
              style: TextStyle(
                fontSize: isSmallScreen ? 11.0 : 12.0,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: _primaryBlue,
                  size: isSmallScreen ? 18.0 : 20.0,
                ),
                SizedBox(width: 8),
                Text(
                  'Current Selection (Live Updates)',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            _buildLiveDetailRow('Location Type', _selectedLocationType == 'auto' ? 'Auto-detected' : 'Manual', isSmallScreen),
            _buildLiveDetailRow('Address', _address.isNotEmpty ? _address : 'Not selected', isSmallScreen),
            _buildLiveDetailRow('Latitude', _latitude.isNotEmpty ? _latitude : '--', isSmallScreen),
            _buildLiveDetailRow('Longitude', _longitude.isNotEmpty ? _longitude : '--', isSmallScreen),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            if (_isTracking)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                decoration: BoxDecoration(
                  color: _accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentTeal.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timeline, color: _accentTeal, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live tracking: $_locationUpdateCount updates, ${_totalDistance.toStringAsFixed(1)}m moved',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                          color: _accentTeal,
                        ),
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

  Widget _buildDetailRow(String title, String value, bool isSmallScreen) {
    final titleWidth = isSmallScreen ? 90.0 : 120.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    final valueFontSize = isSmallScreen ? 13.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3.0 : 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: titleWidth,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: titleFontSize,
                color: _primaryBlue,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDetailRow(String title, String value, bool isSmallScreen) {
    final titleWidth = isSmallScreen ? 90.0 : 120.0;
    final titleFontSize = isSmallScreen ? 13.0 : 14.0;
    final valueFontSize = isSmallScreen ? 13.0 : 14.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3.0 : 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: titleWidth,
            child: Text(
              '$title:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: titleFontSize,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: valueFontSize,
                color: Colors.black87,
                fontWeight: value.contains('Lat:') ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _primaryBlue),
              SizedBox(height: 20),
              Text(
                'Loading location data...',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      drawer: LandOwnerDrawer(
        onLogout: _handleLogout,
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          _buildDashboardHeader(context),
          
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExistingLocationDisplay(),
                        
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        
                        _buildLocationTypeSelection(),
                        
                        if (_selectedLocationType == 'manual') ...[
                          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                          _buildManualLocationInput(),
                        ],
                        
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        
                        _buildTrackingControls(),
                        
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        
                        _buildMapCard(),
                        
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        
                        _buildCurrentLocationCard(),
                        
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveToFirebase,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 14.0 : 16.0,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 10.0 : 12.0
                                ),
                              ),
                              elevation: 4,
                            ),
                            icon: _isSaving
                                ? SizedBox(
                                    height: isSmallScreen ? 18.0 : 20.0,
                                    width: isSmallScreen ? 18.0 : 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Icon(Icons.save, size: isSmallScreen ? 18 : 20),
                            label: _isSaving
                                ? Text('Saving...', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0))
                                : Text(
                                    (widget.existingData != null || _fetchedExistingData != null)
                                        ? 'Update Location'
                                        : 'Save Location',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14.0 : 16.0,
                                    ),
                                  ),
                          ),
                        ),
                        
                        SizedBox(height: isSmallScreen ? 16.0 : 20.0),
                      ],
                    ),
                  ),
                ),
                
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    'Developed By Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _headerTextDark.withOpacity(0.7),
                      fontSize: isSmallScreen ? 11.0 : 12.0,
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