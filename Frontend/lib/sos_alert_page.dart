// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

const Color darkRed = Color(0xFF8B0000);

class SosAlertPage extends StatefulWidget {
  const SosAlertPage({Key? key}) : super(key: key);

  @override
  State<SosAlertPage> createState() => _SosAlertPageState();
}

class _SosAlertPageState extends State<SosAlertPage> {
  List<dynamic> _contacts = [];
  bool _loading = true;
  late String _baseUrl;
  String? _username;

  @override
  void initState() {
    super.initState();
    setBaseUrlAndFetchContacts();
  }

  // ------------------- DETERMINE BASE URL & LOAD USERNAME -------------------
  Future<void> setBaseUrlAndFetchContacts() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _baseUrl = androidInfo.isPhysicalDevice
          ? 'http://10.95.236.185:8080'
          : 'http://10.0.2.2:8080';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _baseUrl = iosInfo.isPhysicalDevice
          ? 'http://10.95.236.185:8080'
          : 'http://localhost:8080';
    } else {
      _baseUrl = 'http://localhost:8080';
    }

    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username');
    await fetchContacts();
  }

  // ------------------- FETCH CONTACTS -------------------
  Future<void> fetchContacts() async {
    setState(() => _loading = true);
    try {
      if (_username == null) {
        setState(() => _loading = false);
        _showErrorSnackBar("User not logged in");
        return;
      }

      final uri =
          Uri.parse('$_baseUrl/api/get_emergency_contacts/?username=$_username');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _contacts = body['contacts'] ?? [];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        _showErrorSnackBar('Failed to fetch contacts: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Error fetching contacts: $e');
    }
  }

  // ------------------- SEND ALERT TO CONTACTS -------------------
  Future<void> sendAlert() async {
    if (_contacts.isEmpty) {
      _showErrorSnackBar('No emergency contacts available!');
      return;
    }

    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackBar('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showErrorSnackBar('Location permission denied.');
          return;
        }
      }

      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _showErrorSnackBar('Failed to get location: $e');
      return;
    }

    final String locationUrl =
        'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

    for (var contact in _contacts) {
      final phone = contact['phone_number'] ?? contact['phone'] ?? '';
      if (phone.isNotEmpty) {
        final fullPhone = phone.startsWith('+') ? phone : '+91$phone';
        final uri = Uri.parse(
            "sms:$fullPhone?body=🚨 SOS Alert! I need help urgently. My location: $locationUrl");

        print('Attempting to send SMS to $fullPhone');
        print('Launch URL: $uri');

        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            _showErrorSnackBar('Could not open SMS app for $fullPhone');
          }
        } catch (e) {
          _showErrorSnackBar('Error launching SMS for $fullPhone: $e');
        }
      }
    }

    _showSuccessSnackBar('SOS alert sent with your location!');
  }

  // ------------------- ADD CONTACT (with 10-digit phone validation) -------------------
  Future<void> addContact(String name, String phone) async {
    if (_username == null) {
      _showErrorSnackBar("User not logged in");
      return;
    }

    // ✅ Phone validation
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(phone)) {
      _showErrorSnackBar("Please enter a valid 10-digit phone number");
      return;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/add_emergency_contact/');
      final bodyMap = {
        'username': _username,
        'name': name,
        'phone_number': phone,
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchContacts();
        _showSuccessSnackBar('Contact added successfully');
      } else {
        final body = jsonDecode(response.body);
        final err = body['error'] ?? body['message'] ?? 'Unknown error';
        _showErrorSnackBar('Failed to add contact: $err');
      }
    } catch (e) {
      _showErrorSnackBar('Error adding contact: $e');
    }
  }

  // ------------------- DELETE CONTACT -------------------
  Future<void> deleteContact(int contactId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete Contact"),
        content:
            const Text("Are you sure you want to delete this emergency contact?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: darkRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final uri =
          Uri.parse('$_baseUrl/api/delete_emergency_contact/$contactId/');
      final response = await http.delete(uri).timeout(const Duration(seconds: 10));

      print('DELETE -> status: ${response.statusCode}');
      print('DELETE -> body: ${response.body}');

      Map<String, dynamic>? respJson;
      try {
        if (response.body.trim().isNotEmpty) {
          respJson = jsonDecode(response.body);
        }
      } catch (e) {
        _showErrorSnackBar('Server returned non-JSON response. Check console.');
        print('JSON decode error: $e');
        return;
      }

      if (response.statusCode == 200 && respJson?['success'] == true) {
        _showSuccessSnackBar('Contact deleted successfully');
        await fetchContacts();
      } else {
        final err = respJson?['error'] ??
            respJson?['message'] ??
            'Failed to delete contact (status ${response.statusCode})';
        _showErrorSnackBar(err.toString());
      }
    } catch (e) {
      _showErrorSnackBar('Error deleting contact: $e');
      print('Delete exception: $e');
    }
  }

  // ------------------- SNACKBAR HELPERS -------------------
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // ------------------- ADD CONTACT DIALOG -------------------
  void showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Emergency Contact"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: darkRed),
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty && phone.isNotEmpty) {
                  addContact(name, phone);
                  Navigator.pop(context);
                } else {
                  _showErrorSnackBar('Please enter name and phone number');
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ------------------- BUILD UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "SOS Alert",
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: darkRed))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: sendAlert,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: darkRed,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "SOS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: sendAlert,
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                      label: const Text(
                        "Send Alert",
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Your Emergency Contacts",
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: darkRed,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _contacts.isEmpty
                          ? const Center(
                              child: Text(
                                "No emergency contacts added yet.",
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                final id = contact['id'];
                                return Card(
                                  elevation: 3,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: darkRed,
                                      child:
                                          Icon(Icons.person, color: Colors.white),
                                    ),
                                    title: Text(
                                      contact['name'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    subtitle: Text(
                                      contact['phone_number'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'Montserrat',
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => deleteContact(id),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: showAddContactDialog,
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add, color: darkRed),
                              SizedBox(width: 8),
                              Text(
                                "Add New Emergency Contact",
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: darkRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
