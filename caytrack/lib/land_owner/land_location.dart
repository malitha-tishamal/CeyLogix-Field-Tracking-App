import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // Location type selection
  String _selectedLocationType = 'auto'; // 'auto' or 'manual'

  // Manual location controllers
  final TextEditingController _manualLatController = TextEditingController();
  final TextEditingController _manualLngController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // OpenStreetMap tile layers
  final List<Map<String, String>> _tileLayers = [
    {
      'name': 'OpenStreetMap Standard',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'attribution': '© OpenStreetMap contributors'
    },
  ];

  int _selectedTileLayer = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeFormData();
    _getCurrentLocation();
  }

  void _initializeFormData() {
    // If editing existing data, populate form fields
    if (widget.existingData != null) {
      // Set location if available
      if (widget.existingData!['latitude'] != null && widget.existingData!['longitude'] != null) {
        final lat = widget.existingData!['latitude'] is String 
            ? double.parse(widget.existingData!['latitude']) 
            : widget.existingData!['latitude'];
        final lng = widget.existingData!['longitude'] is String 
            ? double.parse(widget.existingData!['longitude']) 
            : widget.existingData!['longitude'];
        
        _selectedLocation = LatLng(lat, lng);
        _latitude = lat.toStringAsFixed(6);
        _longitude = lng.toStringAsFixed(6);
        _address = widget.existingData!['address'] ?? '';
        
        // Determine location type based on existing data
        _selectedLocationType = widget.existingData!['locationType'] ?? 'auto';
      }
    }
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
        if (mounted) {
          setState(() {
            _isLoading = false;
            _selectedLocationType = 'manual';
            _currentLocation = const LatLng(6.9271, 79.8612);
            _selectedLocation = _currentLocation;
          });
        }
        _showErrorDialog('Location Service Disabled', 
            'Please enable location services or use manual location selection.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _selectedLocationType = 'manual';
              _currentLocation = const LatLng(6.9271, 79.8612);
              _selectedLocation = _currentLocation;
            });
          }
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _selectedLocationType = 'manual';
            _currentLocation = const LatLng(6.9271, 79.8612);
            _selectedLocation = _currentLocation;
          });
        }
        _showPermissionDeniedDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 15));
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          if (_selectedLocationType == 'auto') {
            _selectedLocation = _currentLocation;
          }
          _isLoading = false;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentLocation!, _zoomLevel);
          }
        });
        
        if (_selectedLocationType == 'auto') {
          await _getAddressFromLatLng(_currentLocation!);
        }
      }
    } catch (e) {
      print('Location error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedLocationType = 'manual';
          _currentLocation = const LatLng(6.9271, 79.8612);
          _selectedLocation = _currentLocation;
        });
      }
      _showErrorDialog('Location Error', 
          'Failed to get current location. Please use manual location selection.');
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('This app needs location permission for automatic location detection. You can use manual location selection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Use Manual Selection'),
          ),
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      }
    } catch (e) {
      print('Geocoding error: $e');
      if (mounted) {
        setState(() {
          _address = '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
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
      
      if (lat != null && lng != null) {
        final newLocation = LatLng(lat, lng);
        setState(() {
          _selectedLocation = newLocation;
          _selectedLocationType = 'manual';
        });
        _getAddressFromLatLng(newLocation);
        _mapController.move(newLocation, _zoomLevel);
        
        // Clear the text fields
        _manualLatController.clear();
        _manualLngController.clear();
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter valid coordinates'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _searchLocation() async {
    if (!mounted) return;
    if (_searchController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a location to search'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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
          final lat = double.parse(result['lat']);
          final lng = double.parse(result['lon']);
          final newLocation = LatLng(lat, lng);
          
          if (mounted) {
            setState(() {
              _selectedLocation = newLocation;
              _selectedLocationType = 'manual';
              _isLoading = false;
            });
          }
          
          _getAddressFromLatLng(newLocation);
          _mapController.move(newLocation, _zoomLevel);
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found: ${result['display_name']}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location not found'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Search failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Search error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<void> _saveToFirebase() async {
    if (!mounted) return;
    
    if (_selectedLocation == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please login to save data'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
        return;
      }

      // Prepare the location data for land_locations collection
      final locationData = {
        'userId': user.uid, // Add user ID to the document
        'address': _address,
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'latitudeString': _latitude,
        'longitudeString': _longitude,
        'locationType': _selectedLocationType,
        'factoryIds': widget.existingData?['factoryIds'] ?? [],
        'createdAt': widget.existingData?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to 'land_locations' collection as a separate document
      final landLocationsRef = _firestore.collection('land_locations');
      
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        // Update existing land location
        await landLocationsRef.doc(widget.existingData!['id']).update(locationData);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location updated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      } else {
        // Create new land location
        final newDocRef = landLocationsRef.doc();
        locationData['id'] = newDocRef.id; // Add the document ID to the data
        
        await newDocRef.set(locationData);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }

      // Call the callback with the saved data
      widget.onLocationSelected(locationData);
      
      // Navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });

    } catch (e) {
      print('Firebase save error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving location: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      });
    }
  }

  Widget _buildLocationTypeSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Location Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildLocationTypeCard(
                    'Auto Location',
                    'Use your current location automatically',
                    Icons.my_location,
                    'auto',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildLocationTypeCard(
                    'Manual Location',
                    'Select location manually on map or enter coordinates',
                    Icons.edit_location_alt,
                    'manual',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTypeCard(String title, String description, IconData icon, String type) {
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
          color: _selectedLocationType == type ? Colors.green[50] : Colors.grey[50],
          border: Border.all(
            color: _selectedLocationType == type ? Colors.green : Colors.grey[300]!,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: _selectedLocationType == type ? Colors.green : Colors.grey, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _selectedLocationType == type ? Colors.green : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: _selectedLocationType == type ? Colors.green[700] : Colors.grey[600],
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Coordinates Manually',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualLatController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _manualLngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _useManualCoordinates,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  child: const Text('Go', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingData != null ? 'Edit Location' : 'Select Location'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Type Selection
                  _buildLocationTypeSelection(),
                  
                  const SizedBox(height: 16),
                  
                  // Manual Coordinates Input (only for manual selection)
                  if (_selectedLocationType == 'manual') ...[
                    _buildManualLocationInput(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Search Bar
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search Location',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter address or place name...',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _searchLocation(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _searchLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                ),
                                child: const Text('Search', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Map
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Map',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _goToCurrentLocation,
                                tooltip: 'Go to current location',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 400,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    center: _currentLocation ?? const LatLng(6.9271, 79.8612),
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
                                                  color: _selectedLocationType == 'auto' ? Colors.green : Colors.blue,
                                                  size: 40,
                                                ),
                                              ),
                                            ]
                                          : [],
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
                  
                  // Location Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selected Location Details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Location Type', 
                              _selectedLocationType == 'auto' ? 'Auto-detected' : 'Manual'),
                          _buildDetailRow('Address', _address.isNotEmpty ? _address : 'Not selected'),
                          _buildDetailRow('Latitude', _latitude.isNotEmpty ? _latitude : '--'),
                          _buildDetailRow('Longitude', _longitude.isNotEmpty ? _longitude : '--'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveToFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          : const Text(
                              'Save Location',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
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
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}