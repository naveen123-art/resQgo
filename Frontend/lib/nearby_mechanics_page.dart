// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'billing_page.dart';
// ignore: unnecessary_import
import 'package:flutter/services.dart'; // For Clipboard fallback

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = 'http://10.95.236.185:8080/api/services/';

class Mechanic {
  final String id;
  final String username;
  final String name;
  final String phone;
  final String place;
  final String description;
  final double latitude;
  final double longitude;

  Mechanic({
    required this.id,
    required this.username,
    required this.name,
    required this.phone,
    required this.place,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  factory Mechanic.fromJson(Map<String, dynamic> json) {
    return Mechanic(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      place: json['place'] ?? '',
      description: json['description'] ?? '',
      latitude: (json['latitude'] != null)
          ? double.tryParse(json['latitude'].toString()) ?? 0.0
          : 0.0,
      longitude: (json['longitude'] != null)
          ? double.tryParse(json['longitude'].toString()) ?? 0.0
          : 0.0,
    );
  }
}

class NearbyMechanicsPage extends StatefulWidget {
  const NearbyMechanicsPage({Key? key}) : super(key: key);

  @override
  State<NearbyMechanicsPage> createState() => _NearbyMechanicsPageState();
}

class _NearbyMechanicsPageState extends State<NearbyMechanicsPage> {
  Future<List<Mechanic>>? _mechanicsFuture;
  List<Mechanic> _allMechanics = [];
  String _searchQuery = '';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    await _getUserLocation();
    setState(() {
      _mechanicsFuture = fetchMechanics();
    });
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<Mechanic>> fetchMechanics() async {
    final url = Uri.parse('${baseUrl}list_mechanics/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      _allMechanics = jsonList.map((json) => Mechanic.fromJson(json)).toList();

      if (_currentPosition != null) {
        _allMechanics.sort((a, b) {
          final distA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a.latitude,
            a.longitude,
          );
          final distB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
      }

      return _allMechanics;
    } else {
      throw Exception('Failed to load mechanics');
    }
  }

  Future<void> _refreshList() async {
    await _getUserLocation();
    setState(() {
      _mechanicsFuture = fetchMechanics();
    });
  }

  List<Mechanic> _filterMechanics(String query) {
    if (query.isEmpty) return _allMechanics;
    final lowerQuery = query.toLowerCase();
    return _allMechanics.where((m) {
      return m.name.toLowerCase().contains(lowerQuery) ||
          m.place.toLowerCase().contains(lowerQuery) ||
          m.description.toLowerCase().contains(lowerQuery) ||
          m.phone.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Mechanics', style: TextStyle(color: Colors.white)),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: _mechanicsFuture == null
          ? const Center(child: CircularProgressIndicator(color: darkRed))
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(size.width * 0.04),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search mechanics...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Mechanic>>(
                    future: _mechanicsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red)),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Text('No mechanics found nearby.'));
                      }

                      final filteredMechanics = _filterMechanics(_searchQuery);

                      return RefreshIndicator(
                        onRefresh: _refreshList,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: size.width * 0.04,
                            vertical: size.height * 0.01,
                          ),
                          itemCount: filteredMechanics.length,
                          itemBuilder: (context, index) {
                            final mechanic = filteredMechanics[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MechanicDetailsPage(mechanic: mechanic),
                                ),
                              ),
                              child: ServiceCard(
                                name: mechanic.name,
                                place: mechanic.place,
                                phone: mechanic.phone,
                                description: mechanic.description,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final String name, place, phone, description;
  const ServiceCard({
    Key? key,
    required this.name,
    required this.place,
    required this.phone,
    required this.description,
  }) : super(key: key);

  Future<void> _launchCall(BuildContext context, String phone) async {
    final cleanedPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final Uri callUri = Uri(scheme: 'tel', path: cleanedPhone);

    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No dialer app found on device')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing call: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Card(
      margin: EdgeInsets.only(bottom: size.height * 0.015),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(size.width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.045,
                    color: darkRed)),
            SizedBox(height: size.height * 0.01),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                SizedBox(width: size.width * 0.02),
                Expanded(child: Text(place, style: TextStyle(fontSize: size.width * 0.035))),
              ],
            ),
            SizedBox(height: size.height * 0.008),
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.grey),
                SizedBox(width: size.width * 0.02),
                Text(phone, style: TextStyle(fontSize: size.width * 0.035)),
                const Spacer(),
                IconButton(
                  onPressed: () => _launchCall(context, phone),
                  icon: const Icon(Icons.call, color: darkRed),
                ),
              ],
            ),
            SizedBox(height: size.height * 0.01),
            Text(description, style: TextStyle(fontSize: size.width * 0.035)),
          ],
        ),
      ),
    );
  }
}

class MechanicDetailsPage extends StatelessWidget {
  final Mechanic mechanic;
  const MechanicDetailsPage({Key? key, required this.mechanic}) : super(key: key);

  Future<void> _confirmService(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsername = prefs.getString('username') ?? 'user';
      final currentPhone = prefs.getString('phone') ?? '9999999999';

      final response = await http.post(
        Uri.parse('${baseUrl}notifications/create/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': mechanic.username,
          'title': 'Service Confirmed',
          'message': '$currentUsername has confirmed your service request.',
          'sender_username': currentUsername,
          'sender_phone': currentPhone,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service confirmed! Notification sent.")),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BillingPage(mechanic: mechanic)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(mechanic.name),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(size.width * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mechanic.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.065,
                    color: darkRed)),
            SizedBox(height: size.height * 0.02),
            Text("Place: ${mechanic.place}", style: TextStyle(fontSize: size.width * 0.04)),
            SizedBox(height: size.height * 0.02),
            Text("Phone: ${mechanic.phone}", style: TextStyle(fontSize: size.width * 0.04)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _confirmService(context),
              icon: const Icon(Icons.check),
              label: const Text("Confirm & Proceed to Billing"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}
