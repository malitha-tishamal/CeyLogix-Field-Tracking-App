// land_location.dart – MODERN COMPACT HEADER (BLUE THEME)
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

class AppColors {
  static const Color background        = Color(0xFFF4F6FA);
  static const Color darkText          = Color(0xFF1A1D26);
  static const Color primaryBlue       = Color(0xFF2764E7);
  static const Color accentRed         = Color(0xFFE53935);
  static const Color accentTeal        = Color(0xFF00BFA5);
  static const Color cardBackground    = Colors.white;
  static const Color secondaryText     = Color(0xFF6A798A);
  static const Color secondaryColor    = Color(0xFF6AD96A);
  static const Color successGreen      = Color(0xFF2E9E5B);
  static const Color warningOrange     = Color(0xFFE8840A);
  static const Color purpleAccent      = Color(0xFF7C3AED);
  static const Color amberAccent       = Color(0xFFF59E0B);
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd   = Color(0xFFF7FAFF);
  static const Color headerTextDark      = Color(0xFF333333);
  static const Color info              = Color(0xFF0EA5E9);
  static const Color textTertiary      = Color(0xFFB0BAC8);
  static const Color hover             = Color(0xFFF8FAFC);
  static const Color border            = Color(0xFFE8ECF2);
}

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

  // Manual polygon points controllers (list of lat/lng pairs)
  List<TextEditingController> _latControllers = [];
  List<TextEditingController> _lngControllers = [];

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

  // Address cache
  final Map<String, String> _addressCache = {};

  // Polygon recording variables (manual or GPS)
  List<LatLng> _polygonPoints = [];
  bool _isRecordingPolygon = false;
  double _polygonArea = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Initialize with 5 default empty point rows
    _initializeManualPointControllers(5);

    _initializeFormData();
    _fetchExistingLocation();
    _getCurrentLocation();
    _fetchHeaderData();
  }

  void _initializeManualPointControllers(int count) {
    for (int i = 0; i < count; i++) {
      _latControllers.add(TextEditingController());
      _lngControllers.add(TextEditingController());
    }
  }

  void _addManualPointRow() {
    setState(() {
      _latControllers.add(TextEditingController());
      _lngControllers.add(TextEditingController());
    });
  }

  void _removeManualPointRow(int index) {
    if (_latControllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one point is required')),
      );
      return;
    }
    setState(() {
      _latControllers[index].dispose();
      _lngControllers[index].dispose();
      _latControllers.removeAt(index);
      _lngControllers.removeAt(index);
    });
  }

  void _applyManualPointsToPolygon() {
    List<LatLng> points = [];
    for (int i = 0; i < _latControllers.length; i++) {
      double? lat = double.tryParse(_latControllers[i].text.trim());
      double? lng = double.tryParse(_lngControllers[i].text.trim());
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        points.add(LatLng(lat, lng));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid coordinates at row ${i + 1}')),
        );
        return;
      }
    }

    if (points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 3 points are required for a polygon')),
      );
      return;
    }

    setState(() {
      _polygonPoints = points;
      _calculatePolygonArea();
      // Use first point as primary location marker
      _selectedLocation = points.first;
      _selectedLocationType = 'manual';
      _getAddressFromLatLng(_selectedLocation!);
      _mapController.move(_selectedLocation!, _zoomLevel);
      // Stop any ongoing GPS tracking if active
      if (_isTracking) _stopRealtimeTracking();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Polygon updated with ${points.length} points. Area: ${_polygonArea.toStringAsFixed(2)} m²'),
        backgroundColor: _primaryBlue,
      ),
    );
  }

  void _clearManualPoints() {
    setState(() {
      for (var c in _latControllers) c.dispose();
      for (var c in _lngControllers) c.dispose();
      _latControllers.clear();
      _lngControllers.clear();
      _initializeManualPointControllers(5); // Reset to 5 empty rows
      _polygonPoints.clear();
      _polygonArea = 0.0;
    });
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
    if (user == null) return;

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
    if (user == null || widget.existingData != null) return;

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
      final lat = data['latitude'] is String ? double.tryParse(data['latitude']) ?? 0.0 : data['latitude'] as double;
      final lng = data['longitude'] is String ? double.tryParse(data['longitude']) ?? 0.0 : data['longitude'] as double;

      _selectedLocation = LatLng(lat, lng);
      _latitude = data['latitudeString'] ?? lat.toStringAsFixed(6);
      _longitude = data['longitudeString'] ?? lng.toStringAsFixed(6);

      _address = data['address'] ?? 'Address not available';
      _selectedLocationType = data['locationType'] ?? 'manual';
    }

    // Load polygon if present
    if (data['polygonPoints'] != null) {
      final points = data['polygonPoints'] as List;
      _polygonPoints = points.map((p) => LatLng((p as GeoPoint).latitude, p.longitude)).toList();
      _calculatePolygonArea();

      // Also populate manual controllers with these points
      for (var c in _latControllers) c.dispose();
      for (var c in _lngControllers) c.dispose();
      _latControllers.clear();
      _lngControllers.clear();
      for (var p in _polygonPoints) {
        _latControllers.add(TextEditingController(text: p.latitude.toStringAsFixed(6)));
        _lngControllers.add(TextEditingController(text: p.longitude.toStringAsFixed(6)));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedLocation != null) {
        _mapController.move(_selectedLocation!, _zoomLevel);
      }
    });
  }

  @override
  void dispose() {
    for (var c in _latControllers) c.dispose();
    for (var c in _lngControllers) c.dispose();
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

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best).timeout(const Duration(seconds: 15));

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
      if (mounted) {
        setState(() {
          _latitude = latLng.latitude.toStringAsFixed(6);
          _longitude = latLng.longitude.toStringAsFixed(6);
        });
      }

      final cacheKey = '${latLng.latitude.toStringAsFixed(6)}_${latLng.longitude.toStringAsFixed(6)}';
      if (_addressCache.containsKey(cacheKey)) {
        if (mounted) {
          setState(() {
            _address = _addressCache[cacheKey]!;
          });
        }
        return;
      }

      String address = '';

      try {
        final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude).timeout(const Duration(seconds: 5));
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
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (e) {
        print('Geocoding package error: $e');
      }

      if (address.isEmpty || address.contains('null')) {
        try {
          address = await _getAddressFromNominatim(latLng);
        } catch (e) {
          print('Nominatim API error: $e');
        }
      }

      if (address.isEmpty) {
        address = 'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lng: ${latLng.longitude.toStringAsFixed(6)}';
      }

      _addressCache[cacheKey] = address;
      if (_addressCache.length > 50) {
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
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'LocationSelectorApp/1.0', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          return data['display_name'] as String;
        } else if (data['address'] != null) {
          final address = data['address'] as Map<String, dynamic>;
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
          if (parts.isNotEmpty) return parts.join(', ');
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

  Future<void> _searchLocation() async {
    if (!mounted || _searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(_searchController.text)}&limit=1&addressdetails=1'),
        headers: {'User-Agent': 'LocationSelectorApp/1.0'},
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
              SnackBar(content: Text('Found: ${result['display_name']}'), backgroundColor: _primaryBlue),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found'), backgroundColor: Colors.red));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Search failed. Please try again.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to save data'), backgroundColor: Colors.red));
        return;
      }

      final String documentId = user.uid;
      final DocumentReference landLocationDocRef = _firestore.collection('land_location').doc(documentId);

      bool isUpdate = _fetchedExistingData != null || widget.existingData != null;

      final locationData = {
        'userId': user.uid,
        'address': _address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'latitudeString': _latitude,
        'longitudeString': _longitude,
        'locationType': _selectedLocationType,
        'polygonPoints': _polygonPoints.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
        'polygonArea': _polygonArea,
        'createdAt': (widget.existingData?['createdAt'] ?? _fetchedExistingData?['createdAt']) ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await landLocationDocRef.set(locationData);

      final String successMessage = isUpdate ? 'Location updated successfully!' : 'Location saved successfully!';
      locationData['docId'] = documentId;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: _primaryBlue));
          widget.onLocationSelected(locationData);
          Navigator.pop(context);
        }
      });
    } catch (e) {
      print('Firebase save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving location: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== REAL-TIME TRACKING & POLYGON RECORDING ====================
  Future<void> _startRealtimeTracking() async {
    try {
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

      setState(() {
        _isTracking = true;
        _locationHistory.clear();
        _totalDistance = 0.0;
        _locationUpdateCount = 0;
      });

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
      ).listen((Position position) {
        if (!mounted) return;

        final newLocation = LatLng(position.latitude, position.longitude);

        setState(() {
          _currentLocation = newLocation;
          _selectedLocation = newLocation;
          _selectedLocationType = 'auto';
          _locationUpdateCount++;
          _locationHistory.add(newLocation);
          if (_locationHistory.length > 100) _locationHistory.removeAt(0);

          if (_lastPosition != null) {
            final distance = Geolocator.distanceBetween(
              _lastPosition!.latitude, _lastPosition!.longitude,
              position.latitude, position.longitude,
            );
            _totalDistance += distance;
          }
          _lastPosition = position;

          if (_isRecordingPolygon) {
            if (_polygonPoints.isEmpty ||
                Geolocator.distanceBetween(_polygonPoints.last.latitude, _polygonPoints.last.longitude, newLocation.latitude, newLocation.longitude) > 5.0) {
              _polygonPoints.add(newLocation);
              _calculatePolygonArea();
            }
          }
        });

        _getAddressFromLatLng(newLocation);
        _mapController.move(newLocation, _zoomLevel);

        if (_locationUpdateCount % 5 == 0 || (_lastVibrationTime == null || DateTime.now().difference(_lastVibrationTime!).inSeconds > 30)) {
          _vibratePhone();
          _lastVibrationTime = DateTime.now();
        }

        if (_totalDistance > 100 && _locationUpdateCount % 10 == 0) {
          _showTrackingNotification();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Real-time tracking started! Phone will vibrate on updates.'), backgroundColor: _secondaryColor, duration: const Duration(seconds: 3)),
      );
    } catch (e) {
      print('Tracking error: $e');
      setState(() => _isTracking = false);
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
        _isRecordingPolygon = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracking stopped. Total distance: ${_totalDistance.toStringAsFixed(2)} meters'), backgroundColor: _accentRed, duration: const Duration(seconds: 3)),
      );
    }
  }

  void _startRecordingPolygon() async {
    if (!_isTracking) await _startRealtimeTracking();
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isRecordingPolygon = true;
      _polygonPoints.clear();
      _polygonArea = 0.0;
    });
  }

  void _stopRecordingPolygon() {
    setState(() {
      _isRecordingPolygon = false;
      if (_polygonPoints.isNotEmpty && _polygonPoints.last != _polygonPoints.first) {
        _polygonPoints.add(_polygonPoints.first);
      }
      _calculatePolygonArea();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Polygon recording stopped. ${_polygonPoints.length} points recorded.'), backgroundColor: _primaryBlue, duration: const Duration(seconds: 2)),
    );
  }

  void _clearPolygon() {
    setState(() {
      _polygonPoints.clear();
      _polygonArea = 0.0;
      // Also clear manual inputs but keep 5 empty rows
      for (var c in _latControllers) c.clear();
      for (var c in _lngControllers) c.clear();
    });
  }

  void _calculatePolygonArea() {
    if (_polygonPoints.length < 3) {
      _polygonArea = 0.0;
      return;
    }
    double area = 0.0;
    int n = _polygonPoints.length;
    for (int i = 0; i < n; i++) {
      var p1 = _polygonPoints[i];
      var p2 = _polygonPoints[(i + 1) % n];
      area += p1.latitude * p2.longitude - p2.latitude * p1.longitude;
    }
    area = area.abs() / 2.0;
    _polygonArea = area * 111111.0 * 111111.0;
    setState(() {});
  }

  Future<void> _vibratePhone() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [200, 100, 200]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📍 Location updated!\nLat: $_latitude, Lng: $_longitude'), backgroundColor: _primaryBlue.withOpacity(0.8), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(10)),
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
        title: const Row(children: [Icon(Icons.track_changes, color: Colors.green), SizedBox(width: 10), Text('Live Tracking Active')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 Updates: $_locationUpdateCount'),
            Text('📏 Distance: ${_totalDistance.toStringAsFixed(2)} m'),
            Text('📍 Lat: $_latitude'),
            Text('📍 Lng: $_longitude'),
            if (_address.isNotEmpty) ...[const SizedBox(height: 10), Text('🏠 Address: $_address')],
            if (_polygonPoints.isNotEmpty) ...[const SizedBox(height: 10), Text('📐 Polygon points: ${_polygonPoints.length}'), Text('📏 Area: ${_polygonArea.toStringAsFixed(2)} m²')],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ElevatedButton(onPressed: () { Navigator.pop(context); _stopRealtimeTracking(); }, style: ElevatedButton.styleFrom(backgroundColor: _accentRed), child: const Text('Stop Tracking', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildTrackingControls() {
    final isSmallScreen = _screenWidth < 360;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Real-time Tracking', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: _primaryBlue)),
                Switch(value: _isTracking, onChanged: (value) => value ? _startRealtimeTracking() : _stopRealtimeTracking(), activeColor: _secondaryColor, activeTrackColor: _secondaryColor.withOpacity(0.5)),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            if (_isTracking) ...[
              Row(children: [Icon(Icons.timeline, color: _accentTeal, size: 18), const SizedBox(width: 8), Expanded(child: Text('Live tracking active - Phone vibrating on updates', style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0, color: _accentTeal, fontWeight: FontWeight.w500)))]),
              const SizedBox(height: 8),
              _buildDetailRow('Updates', '$_locationUpdateCount', isSmallScreen),
              _buildDetailRow('Distance', '${_totalDistance.toStringAsFixed(2)} m', isSmallScreen),
              _buildDetailRow('History', '${_locationHistory.length} points', isSmallScreen),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(onPressed: _isRecordingPolygon ? _stopRecordingPolygon : _startRecordingPolygon, icon: Icon(_isRecordingPolygon ? Icons.stop : Icons.fiber_manual_record, color: _isRecordingPolygon ? Colors.orange : Colors.red), label: Text(_isRecordingPolygon ? 'Stop Recording' : 'Start Recording'), style: ElevatedButton.styleFrom(backgroundColor: _isRecordingPolygon ? Colors.orange.shade100 : Colors.red.shade100)),
                  if (_polygonPoints.isNotEmpty) ElevatedButton.icon(onPressed: _clearPolygon, icon: Icon(Icons.delete, color: Colors.grey[700]), label: const Text('Clear'), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200)),
                ],
              ),
              if (_polygonPoints.isNotEmpty) ...[const SizedBox(height: 8), _buildDetailRow('Polygon Points', '${_polygonPoints.length}', isSmallScreen), _buildDetailRow('Area', '${_polygonArea.toStringAsFixed(2)} m²', isSmallScreen)],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _showTrackingNotification, icon: const Icon(Icons.notifications_active, size: 18), label: const Text('Show Live Data'), style: ElevatedButton.styleFrom(backgroundColor: _accentTeal, foregroundColor: Colors.white))),
            ] else ...[
              Row(children: [Icon(Icons.info, color: Colors.orange, size: 18), const SizedBox(width: 8), Expanded(child: Text('Enable real-time tracking for live updates with vibration', style: TextStyle(fontSize: isSmallScreen ? 12.0 : 13.0, color: Colors.orange[800])))]),
              const SizedBox(height: 8),
              Text('• Updates every 5 meters\n• Phone vibrates on location change\n• High accuracy GPS', style: TextStyle(fontSize: isSmallScreen ? 11.0 : 12.0, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ENHANCED MANUAL POLYGON INPUT (5 default rows + Add button) ====================
  Widget _buildManualPolygonInput() {
    final isSmallScreen = _screenWidth < 360;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manual Polygon Points', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: _primaryBlue)),
            const SizedBox(height: 8),
            Text('Enter coordinates for at least 3 points (latitude, longitude).', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            ...List.generate(_latControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Point ${index + 1} Lat',
                          hintText: 'e.g., 6.9271',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Point ${index + 1} Lng',
                          hintText: 'e.g., 79.8612',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeManualPointRow(index),
                      tooltip: 'Remove this point',
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        ElevatedButton.icon(
          onPressed: _addManualPointRow,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Point'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentTeal,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _clearManualPoints,
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),

    const SizedBox(height: 12),

    // New line
    ElevatedButton.icon(
      onPressed: _applyManualPointsToPolygon,
      icon: const Icon(Icons.polyline, size: 18),
      label: const Text('Apply Points'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
    ),
  ],
)
          ],
        ),
      ),
    );
  }

  // ==================== EXISTING LOCATION DISPLAY ====================
  Widget _buildExistingLocationDisplay() {
    final User? user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final Map<String, dynamic>? savedData = _fetchedExistingData ?? widget.existingData;
    if (savedData == null || savedData.isEmpty) return const SizedBox.shrink();

    final displayLat = savedData['latitudeString'] ?? savedData['latitude']?.toStringAsFixed(6) ?? '--';
    final displayLng = savedData['longitudeString'] ?? savedData['longitude']?.toStringAsFixed(6) ?? '--';
    final displayAddress = savedData['address'] ?? 'Address not available';

    double? savedLat, savedLng;
    try {
      savedLat = (savedData['latitude'] as num?)?.toDouble();
      savedLng = (savedData['longitude'] as num?)?.toDouble();
    } catch (e) {}

    final openMapUrl = 'https://www.google.com/maps/search/?api=1&query=$displayLat,$displayLng';
    final isSmallScreen = _screenWidth < 360;

    return Card(
      color: Colors.grey[100],
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0), side: BorderSide(color: Colors.grey[300]!, width: 1)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.location_history, color: Colors.grey[700], size: isSmallScreen ? 20.0 : 24.0), const SizedBox(width: 8), Expanded(child: Text('Previously Saved Location', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const Divider(color: Color(0xFFE0E0E0)),
            _buildDetailRow('Saved Address', displayAddress, isSmallScreen),
            _buildDetailRow('Latitude', displayLat, isSmallScreen),
            _buildDetailRow('Longitude', displayLng, isSmallScreen),
            _buildDetailRow('Updated At', (savedData['updatedAt'] is Timestamp) ? (savedData['updatedAt'] as Timestamp).toDate().toString().split('.')[0] : 'N/A', isSmallScreen),
            if (savedData['polygonPoints'] != null) ...[
              _buildDetailRow('Polygon Points', '${(savedData['polygonPoints'] as List).length}', isSmallScreen),
              _buildDetailRow('Area', savedData['polygonArea'] != null ? '${savedData['polygonArea'].toStringAsFixed(2)} m²' : '--', isSmallScreen),
            ],
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            if (savedLat != null && savedLng != null)
              Column(
                children: [
                  if (isSmallScreen)
                    Column(
                      children: [
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _mapController.move(LatLng(savedLat!, savedLng!), _zoomLevel), icon: Icon(Icons.travel_explore, size: 16, color: Colors.grey[700]), label: Text('View on Map', style: TextStyle(fontSize: 13, color: Colors.grey[700])), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () async { if (await canLaunchUrlString(openMapUrl)) await launchUrlString(openMapUrl); }, icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white), label: const Text('Open in Maps', style: TextStyle(fontSize: 13, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: ElevatedButton.icon(onPressed: () => _mapController.move(LatLng(savedLat!, savedLng!), _zoomLevel), icon: Icon(Icons.travel_explore, size: 18, color: Colors.grey[700]), label: Text('View on Map', style: TextStyle(fontSize: 14, color: Colors.grey[700])), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.grey[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                        const SizedBox(width: 8),
                        Expanded(child: ElevatedButton.icon(onPressed: () async { if (await canLaunchUrlString(openMapUrl)) await launchUrlString(openMapUrl); }, icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white), label: const Text('Open in Maps', style: TextStyle(fontSize: 14, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                      ],
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Text('You can update a new location by selecting a point on the map below or by entering polygon points manually.', style: TextStyle(fontStyle: FontStyle.italic, color: const Color.fromARGB(255, 113, 121, 212), fontSize: isSmallScreen ? 12.0 : 13.0)),
          ],
        ),
      ),
    );
  }

  // ==================== LOCATION TYPE SELECTION ====================
  Widget _buildLocationTypeSelection() {
    final isSmallScreen = _screenWidth < 360;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Location Method', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: _primaryBlue)),
            const SizedBox(height: 12),
            if (isSmallScreen)
              Column(children: [
                _buildLocationTypeCard('Auto Location', 'Use current location', Icons.my_location, 'auto', isSmallScreen),
                const SizedBox(height: 8),
                _buildLocationTypeCard('Manual Location', 'Select on map or enter coordinates', Icons.edit_location_alt, 'manual', isSmallScreen),
              ])
            else
              Row(children: [
                Expanded(child: _buildLocationTypeCard('Auto Location', 'Use your current location automatically', Icons.my_location, 'auto', isSmallScreen)),
                const SizedBox(width: 12),
                Expanded(child: _buildLocationTypeCard('Manual Location', 'Select location manually on map or enter coordinates', Icons.edit_location_alt, 'manual', isSmallScreen)),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTypeCard(String title, String description, IconData icon, String type, bool isSmallScreen) {
    final bool isSelected = _selectedLocationType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLocationType = type;
          if (type == 'auto' && _currentLocation != null) {
            _selectedLocation = _currentLocation;
            _getAddressFromLatLng(_currentLocation!);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        decoration: BoxDecoration(
          color: isSelected ? _primaryBlue.withOpacity(0.15) : Colors.grey[50],
          border: Border.all(color: isSelected ? _primaryBlue : Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? _primaryBlue : Colors.grey, size: isSmallScreen ? 24.0 : 32.0),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isSmallScreen ? 12.0 : 14.0, color: isSelected ? _primaryBlue : Colors.grey[700]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(description, style: TextStyle(fontSize: isSmallScreen ? 10.0 : 12.0, color: isSelected ? _primaryBlue : Colors.grey[600]), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ==================== MAP CARD ====================
  Widget _buildMapCard() {
    final isSmallScreen = _screenWidth < 360;
    final mapHeight = isSmallScreen ? _screenHeight * 0.35 : _screenHeight * 0.4;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Interactive Map', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: _primaryBlue)),
                Row(children: [
                  IconButton(onPressed: _goToCurrentLocation, icon: Icon(Icons.my_location, color: _primaryBlue, size: isSmallScreen ? 20.0 : 24.0), padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0), constraints: BoxConstraints(minWidth: isSmallScreen ? 36.0 : 40.0, minHeight: isSmallScreen ? 36.0 : 40.0), tooltip: 'Go to current location'),
                  IconButton(onPressed: () { if (_selectedLocation != null) _mapController.move(_selectedLocation!, _zoomLevel); }, icon: Icon(Icons.center_focus_strong, color: _primaryBlue, size: isSmallScreen ? 20.0 : 24.0), padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0), constraints: BoxConstraints(minWidth: isSmallScreen ? 36.0 : 40.0, minHeight: isSmallScreen ? 36.0 : 40.0), tooltip: 'Center on selected location'),
                ]),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            Container(
              height: mapHeight,
              decoration: BoxDecoration(border: Border.all(color: _primaryBlue.withOpacity(0.3)), borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(center: _selectedLocation ?? const LatLng(6.9271, 79.8612), zoom: _zoomLevel, onTap: _onMapTap),
                children: [
                  TileLayer(urlTemplate: _tileLayers[_selectedTileLayer]['url'], userAgentPackageName: 'com.example.location_selector'),
                  PolygonLayer(polygons: _polygonPoints.isNotEmpty ? [Polygon(points: _polygonPoints, color: _primaryBlue.withOpacity(0.4), borderStrokeWidth: 2.0, borderColor: _primaryBlue, isFilled: true)] : []),
                  MarkerLayer(markers: _selectedLocation != null ? [Marker(point: _selectedLocation!, width: isSmallScreen ? 32.0 : 40.0, height: isSmallScreen ? 32.0 : 40.0, child: Icon(Icons.location_pin, color: _selectedLocationType == 'auto' ? _secondaryColor : _primaryBlue, size: isSmallScreen ? 32.0 : 40.0))] : []),
                  RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors', onTap: () => launchUrlString('https://openstreetmap.org/copyright'))]),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            Text('Tap anywhere on the map to select a location', style: TextStyle(fontSize: isSmallScreen ? 11.0 : 12.0, color: Colors.grey[600], fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ==================== CURRENT LOCATION CARD ====================
  Widget _buildCurrentLocationCard() {
    final isSmallScreen = _screenWidth < 360;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.location_on, color: _primaryBlue, size: isSmallScreen ? 18.0 : 20.0), const SizedBox(width: 8), Text('Current Selection (Live Updates)', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0, fontWeight: FontWeight.bold, color: _primaryBlue))]),
            const SizedBox(height: 12),
            _buildLiveDetailRow('Location Type', _selectedLocationType == 'auto' ? 'Auto-detected' : 'Manual', isSmallScreen),
            _buildLiveDetailRow('Address', _address.isNotEmpty ? _address : 'Not selected', isSmallScreen),
            _buildLiveDetailRow('Latitude', _latitude.isNotEmpty ? _latitude : '--', isSmallScreen),
            _buildLiveDetailRow('Longitude', _longitude.isNotEmpty ? _longitude : '--', isSmallScreen),
            if (_polygonPoints.isNotEmpty) ...[
              _buildLiveDetailRow('Polygon Points', '${_polygonPoints.length}', isSmallScreen),
              _buildLiveDetailRow('Area', '${_polygonArea.toStringAsFixed(2)} m²', isSmallScreen),
            ],
            const SizedBox(height: 12),
            if (_isTracking)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                decoration: BoxDecoration(color: _accentTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _accentTeal.withOpacity(0.3))),
                child: Row(children: [Icon(Icons.timeline, color: _accentTeal, size: 16), const SizedBox(width: 8), Expanded(child: Text('Live tracking: $_locationUpdateCount updates, ${_totalDistance.toStringAsFixed(1)}m moved', style: TextStyle(fontSize: isSmallScreen ? 11.0 : 12.0, color: _accentTeal)))]),
              ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildDetailRow(String title, String value, bool isSmallScreen) {
    final titleWidth = isSmallScreen ? 90.0 : 120.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3.0 : 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: titleWidth, child: Text('$title:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: isSmallScreen ? 13.0 : 14.0, color: _primaryBlue))),
          Expanded(child: Text(value, style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildLiveDetailRow(String title, String value, bool isSmallScreen) {
    final titleWidth = isSmallScreen ? 90.0 : 120.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3.0 : 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: titleWidth, child: Text('$title:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: isSmallScreen ? 13.0 : 14.0, color: Colors.grey[700]))),
          Expanded(child: Text(value, style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0, color: Colors.black87, fontWeight: value.contains('Lat:') ? FontWeight.normal : FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ==================== MODERN COMPACT HEADER (BLUE THEME) ====================
  Widget _buildDashboardHeader(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sm = w < 360;
    final md = w >= 360 && w < 400;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 2,
        left: 16,
        right: 16,
        bottom: 12,
      ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu,
                    color: _headerTextDark,
                    size: 24,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loggedInUserName,
                    style: TextStyle(
                      fontSize: sm ? 14 : md ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    )),
                  const SizedBox(height: 3),
                  Text('Land Name: $_landName',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                  Text('($_userRole)',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                ],
              ),
              const Spacer(),
              _buildAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select Land Location',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) =>
            setState(() => _profileImageUrl = null),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: _primaryBlue.withOpacity(0.15),
      child:
          const Icon(Icons.person, color: _primaryBlue, size: 40),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title, style: TextStyle(color: _primaryBlue)), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK', style: TextStyle(color: _primaryBlue)))]));
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _primaryBlue), const SizedBox(height: 20), Text('Loading location data...', style: TextStyle(color: _primaryBlue, fontSize: 16))])),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      drawer: LandOwnerDrawer(onLogout: _handleLogout, onNavigate: _handleDrawerNavigate),
      body: Column(
        children: [
          _buildDashboardHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExistingLocationDisplay(),
                  const SizedBox(height: 16),
                  _buildLocationTypeSelection(),
                  const SizedBox(height: 16),
                  if (_selectedLocationType == 'manual') ...[
                    _buildManualPolygonInput(),
                    const SizedBox(height: 16),
                  ],
                  _buildTrackingControls(),
                  const SizedBox(height: 16),
                  _buildMapCard(),
                  const SizedBox(height: 16),
                  _buildCurrentLocationCard(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveToFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14.0 : 16.0, horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
                        elevation: 4,
                      ),
                      icon: _isSaving
                          ? SizedBox(height: isSmallScreen ? 18.0 : 20.0, width: isSmallScreen ? 18.0 : 20.0, child: const CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : Icon(Icons.save, size: isSmallScreen ? 18 : 20),
                      label: _isSaving
                          ? Text('Saving...', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0))
                          : Text((widget.existingData != null || _fetchedExistingData != null) ? 'Update Location' : 'Save Location', style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0), child: Text('Developed By Malitha Tishamal', textAlign: TextAlign.center, style: TextStyle(color: _headerTextDark.withOpacity(0.7), fontSize: isSmallScreen ? 11.0 : 12.0))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}