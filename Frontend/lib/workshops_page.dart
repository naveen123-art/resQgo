import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'workshop_billing_page.dart';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = 'http://10.95.236.185:8080/api/services/';

class Workshop {
  final String id;
  final String username;
  final String name;
  final String phone;
  final String place;
  final String description;
  double? latitude;
  double? longitude;
  double? distance;

  Workshop({
    required this.id,
    required this.username,
    required this.name,
    required this.phone,
    required this.place,
    required this.description,
    this.latitude,
    this.longitude,
    this.distance,
  });

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'].toString(),
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      place: json['place'] ?? '',
      description: json['description'] ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? 0.0,
    );
  }
}

class WorkshopListPage extends StatefulWidget {
  const WorkshopListPage({Key? key}) : super(key: key);

  @override
  State<WorkshopListPage> createState() => _WorkshopListPageState();
}

class _WorkshopListPageState extends State<WorkshopListPage> {
  Future<List<Workshop>> _workshopsFuture = Future.value([]);
  List<Workshop> _allWorkshops = [];
  List<Workshop> _filteredWorkshops = [];
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initLocationAndFetch() async {
    await _getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _workshopsFuture = fetchWorkshops();
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<List<Workshop>> fetchWorkshops() async {
    final url = Uri.parse('${baseUrl}list_workshops/');
    print('📡 Fetching workshops from: $url');

    final response = await http.get(url);
    print('🔍 Response status: ${response.statusCode}');
    print('🧾 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      _allWorkshops = jsonList.map((json) => Workshop.fromJson(json)).toList();

      if (_currentPosition != null) {
        for (var w in _allWorkshops) {
          if (w.latitude != null && w.longitude != null) {
            w.distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              w.latitude!,
              w.longitude!,
            );
          }
        }
        _allWorkshops.sort((a, b) {
          double da = a.distance ?? double.infinity;
          double db = b.distance ?? double.infinity;
          return da.compareTo(db);
        });
      }

      _filteredWorkshops = _allWorkshops;
      return _allWorkshops;
    } else {
      throw Exception('Failed to load workshops (Status: ${response.statusCode})');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredWorkshops = _allWorkshops.where((workshop) {
        return workshop.name.toLowerCase().contains(query) ||
            workshop.place.toLowerCase().contains(query) ||
            workshop.description.toLowerCase().contains(query) ||
            workshop.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _refreshList() async {
    await _getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _workshopsFuture = fetchWorkshops();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Workshops', style: TextStyle(color: Colors.white)),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(size.width * 0.04),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search workshops...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Workshop>>(
              future: _workshopsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                } else if (_filteredWorkshops.isEmpty) {
                  return const Center(child: Text('No workshops found nearby.'));
                }

                return RefreshIndicator(
                  onRefresh: _refreshList,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                    itemCount: _filteredWorkshops.length,
                    itemBuilder: (context, index) {
                      final workshop = _filteredWorkshops[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkshopDetailsPage(workshop: workshop),
                          ),
                        ),
                        child: ServiceCard(
                          name: workshop.name,
                          place: workshop.place,
                          phone: workshop.phone,
                          description: workshop.description,
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
    final String telUrl = 'tel:$phone';
    final Uri uri = Uri.parse(telUrl);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw 'Could not launch $telUrl';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open dialer: $e')),
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
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                Expanded(
                    child: Text(place,
                        style: TextStyle(fontSize: size.width * 0.035))),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: Colors.grey),
                Text(phone, style: TextStyle(fontSize: size.width * 0.035)),
                const Spacer(),
                IconButton(
                  onPressed: () => _launchCall(context, phone),
                  icon: const Icon(Icons.call, color: darkRed),
                ),
              ],
            ),
            Text(description, style: TextStyle(fontSize: size.width * 0.035)),
          ],
        ),
      ),
    );
  }
}

class WorkshopDetailsPage extends StatelessWidget {
  final Workshop workshop;
  const WorkshopDetailsPage({Key? key, required this.workshop}) : super(key: key);

  Future<void> _confirmService(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUsername = prefs.getString('username') ?? 'user';
      final currentPhone = prefs.getString('phone') ?? '9999999999';

      final response = await http.post(
        Uri.parse('${baseUrl}notifications/create/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': workshop.username,
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
        MaterialPageRoute(builder: (_) => WorkshopBillingPage(workshop: workshop)),
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
        title: Text(workshop.name),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(size.width * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workshop.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: size.width * 0.065,
                    color: darkRed)),
            SizedBox(height: size.height * 0.02),
            Text("Place: ${workshop.place}", style: TextStyle(fontSize: size.width * 0.04)),
            SizedBox(height: size.height * 0.02),
            Text("Phone: ${workshop.phone}", style: TextStyle(fontSize: size.width * 0.04)),
            SizedBox(height: size.height * 0.02),
            Text("Description: ${workshop.description}",
                style: TextStyle(fontSize: size.width * 0.04)),
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
