// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_alert_page.dart';
import 'nearby_mechanics_page.dart';
import 'workshops_page.dart';
import 'profile_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

const Color darkRed = Color(0xFF8B0000);

class ResQGoHomePage extends StatefulWidget {
  final String username;
  final String location;
  final String accountType;

  const ResQGoHomePage({
    Key? key,
    required this.username,
    required this.location,
    required this.accountType,
  }) : super(key: key);

  @override
  State<ResQGoHomePage> createState() => _ResQGoHomePageState();
}

class _ResQGoHomePageState extends State<ResQGoHomePage> {
  late String username;
  late String location;
  late String accountType;
  late String email;
  String latLon = '';
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    username = widget.username;
    location = widget.location;
    accountType = widget.accountType;
    email = '';
    _loadEmail();
    _getCurrentLocation(); // ✅ Added — ensures location fetched on load
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      email = prefs.getString('email') ?? '';
    });
  }

  Future<void> _refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? username;
      location = prefs.getString('location') ?? location;
      accountType = prefs.getString('account_type') ?? accountType;
      email = prefs.getString('email') ?? email;
    });
  }

  // ✅ Fetch current location once
  Future<void> _getCurrentLocation() async {
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

    // ✅ Get current position
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    latLon =
        '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';

    // ✅ Convert to address
    String loc = latLon;
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        loc =
            '${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}';
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }

    setState(() {
      location = loc;
    });

    // ✅ Start background updates
    _startLocationUpdates();
  }

  // ----------------- LIVE LOCATION STREAM -----------------
  Future<void> _startLocationUpdates() async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position pos) async {
      latLon =
          '${pos.latitude.toStringAsFixed(5)},${pos.longitude.toStringAsFixed(5)}';
      String loc = latLon;
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          loc =
              '${place.locality}, ${place.subAdministrativeArea}, ${place.administrativeArea}';
        }
      } catch (e) {
        print('Error in reverse geocoding: $e');
      }
      setState(() {
        location = loc;
      });
    });
  }

  // ----------------- OPEN LOCATION IN GOOGLE MAPS -----------------
  Future<void> _openMap() async {
    if (latLon.isNotEmpty) {
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latLon');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Hello, $username',
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
                  const SizedBox(width: 6),
                  if (latLon.isNotEmpty)
                    GestureDetector(
                      onTap: _openMap,
                      child: const Icon(Icons.map, color: darkRed, size: 22),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SosAlertPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkRed,
                        shape: const CircleBorder(),
                        elevation: 12,
                      ),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.bold,
                            fontSize: 48,
                            color: Colors.white,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _InfoBox(
                            title: 'Nearby Mechanics',
                            icon: Icons.build,
                            color: darkRed,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NearbyMechanicsPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoBox(
                            title: 'Workshops',
                            icon: Icons.home_repair_service,
                            color: darkRed,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const WorkshopListPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoBox(
                            title: 'Emergency Helpline',
                            icon: Icons.warning_amber_rounded,
                            color: darkRed,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const EmergencyHelplinePage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.person, color: darkRed, size: 32),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      username: username,
                      location: location,
                      email: email,
                    ),
                  ),
                );
                _refreshData();
              },
            ),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: darkRed,
              ),
              child: IconButton(
                icon: const Icon(Icons.home, color: Colors.white, size: 36),
                onPressed: () {},
              ),
            ),
            IconButton(
              icon: const Icon(Icons.medical_services,
                  color: darkRed, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyGuidancePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- InfoBox -------------------
class _InfoBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InfoBox({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
        child: SizedBox(
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------- Emergency Helpline Page -------------------
class EmergencyHelplinePage extends StatelessWidget {
  const EmergencyHelplinePage({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> helplines = const [
    {
      "title": "🚔 POLICE & SAFETY",
      "numbers": [
        {"label": "Police", "number": "100"},
        {"label": "Women Helpline", "number": "1091"},
        {"label": "Child Helpline", "number": "1098"},
        {"label": "Cyber Crime Helpline", "number": "1930"},
        {"label": "Senior Citizens Helpline", "number": "1090"},
      ],
    },
    {
      "title": "🚑 MEDICAL & FIRE",
      "numbers": [
        {"label": "Ambulance", "number": "108"},
        {"label": "Fire & Rescue", "number": "101"},
        {"label": "Disaster Management / Control Room", "number": "1077"},
      ],
    },
    {
      "title": "🚨 OTHER ESSENTIAL NUMBERS",
      "numbers": [
        {"label": "Kerala Police (All-in-one)", "number": "112"},
        {"label": "Highway Helpline", "number": "1033"},
        {"label": "Coastal Police", "number": "1093"},
        {"label": "Kerala Tourism", "number": "18004254747"},
        {"label": "Electricity (KSEB)", "number": "1912"},
        {"label": "Water Authority (KWA)", "number": "1916"},
      ],
    },
  ];

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $number';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Helpline'),
        backgroundColor: darkRed,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: helplines.length,
        itemBuilder: (context, index) {
          final section = helplines[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              collapsedIconColor: darkRed,
              iconColor: darkRed,
              title: Text(
                section['title']!,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: darkRed,
                ),
              ),
              children: section['numbers'].map<Widget>((item) {
                return ListTile(
                  leading: const Icon(Icons.phone, color: darkRed),
                  title: Text('${item['label']}: ${item['number']}',
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                      )),
                  trailing: IconButton(
                    icon: const Icon(Icons.call, color: darkRed),
                    onPressed: () => _makeCall(item['number']),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ------------------- Emergency Guidance Page -------------------
class EmergencyGuidancePage extends StatelessWidget {
  const EmergencyGuidancePage({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> guidanceSections = const [
    {
      "title": "1. If Your Vehicle Breaks Down",
      "points": [
        "Move to safety: Pull over to the side of the road, turn on hazard lights.",
        "Stay visible: Place reflective triangles or warning cones 10–15 meters behind.",
        "Stay inside if unsafe: Remain with seatbelt on or exit from passenger side if safe."
      ],
    },
    {
      "title": "2. In Case of Fire or Smoke",
      "points": [
        "Stop vehicle, turn off engine, evacuate everyone at least 50m away.",
        "Do not open hood fully; use dry powder extinguisher if flames are small.",
        "Call fire department or emergency services."
      ],
    },
    {
      "title": "3. In Case of an Accident",
      "points": [
        "Check injuries, switch off ignition, apply handbrake, warn other drivers.",
        "Call emergency helplines: Police 100, Ambulance 108/102, Fire 101.",
        "Exchange details if minor accident."
      ],
    },
    {
      "title": "4. Basic Emergency Items to Keep in Your Car",
      "points": [
        "First aid kit, Fire extinguisher, Reflective warning triangle, Torch/flashlight, Jumper cables, Tow rope, Spare tire and tools, Power bank, Emergency contact numbers"
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Emergency Guidance'),
        backgroundColor: darkRed,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: guidanceSections.map((section) {
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              collapsedIconColor: darkRed,
              iconColor: darkRed,
              title: Text(
                section['title']!,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: darkRed,
                ),
              ),
              children: (section['points'] as List<String>).map<Widget>((point) {
                return ListTile(
                  leading: const Icon(Icons.arrow_right, color: darkRed),
                  title: Text(point,
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontSize: 14)),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
