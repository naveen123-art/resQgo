import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'service_provider_profile_page.dart';
import 'addservice.dart';
import 'service_provider_notification_page.dart';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = "http://10.95.236.185:8080/api/services";

class ServiceProviderHomePage extends StatefulWidget {
  final String username;

  const ServiceProviderHomePage({Key? key, required this.username}) : super(key: key);

  @override
  State<ServiceProviderHomePage> createState() => _ServiceProviderHomePageState();
}

class _ServiceProviderHomePageState extends State<ServiceProviderHomePage> {
  bool isLoading = false;
  int _selectedIndex = 1;
  String location = "Fetching location...";
  Stream<Position>? _positionStream;

  List<dynamic> currentServices = [];

  @override
  void initState() {
    super.initState();
    fetchCurrentServices();
    _startLocationUpdates();
  }

  // ✅ Fetch current services from backend
  Future<void> fetchCurrentServices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_provider_services/${widget.username}/'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentServices = data;
        });
      } else {
        debugPrint("Failed to fetch services: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
    }
  }

  // ----------------- LIVE LOCATION -----------------
  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => location = 'Location services disabled');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => location = 'Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => location = 'Location permission permanently denied');
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    _positionStream!.listen((Position pos) async {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            location = "${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
          });
        } else {
          setState(() {
            location = "Lat: ${pos.latitude.toStringAsFixed(5)}, Lon: ${pos.longitude.toStringAsFixed(5)}";
          });
        }
      } catch (e) {
        setState(() {
          location = "Unable to fetch address";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await fetchCurrentServices();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: height * 0.03),
                Center(
                  child: Text(
                    'Hello, ${widget.username}',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: darkRed,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: darkRed, size: 22),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ✅ Current Services List
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.06),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Current Services",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkRed,
                        ),
                      ),
                      const SizedBox(height: 10),
                      currentServices.isEmpty
                          ? const Text(
                              "No active services yet.",
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: currentServices.length,
                              itemBuilder: (context, index) {
                                final service = currentServices[index];
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    title: Text(service['service_name'] ?? "Unnamed"),
                                    subtitle: Text("Category: ${service['category']}"),
                                    trailing: Text(
                                      "₹${service['price']}",
                                      style: const TextStyle(color: darkRed, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // Add Service Button
                Center(
                  child: Card(
                    color: darkRed,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddServicePage(username: widget.username)),
                        );
                        fetchCurrentServices();
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: width * 0.7,
                        height: height * 0.08,
                        alignment: Alignment.center,
                        child: const Text(
                          "Add Service",
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ✅ Bottom Navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: darkRed,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: "Notifications"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
        onTap: (index) async {
          if (index == 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceProviderNotificationPage(username: widget.username),
              ),
            );
            setState(() => _selectedIndex = 1);
          } else if (index == 2) {
            final prefs = await SharedPreferences.getInstance();
            final username = prefs.getString('username') ?? widget.username;
            final accountType = prefs.getString('account_type') ?? 'service_provider';
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceProviderProfilePage(username: username, accountType: accountType),
              ),
            );
            fetchCurrentServices();
            setState(() {
              _selectedIndex = 1;
            });
          }
        },
      ),
    );
  }
}
