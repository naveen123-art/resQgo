// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import ' resqgo_auth_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = "http://10.95.236.185:8080";

class ProfilePage extends StatefulWidget {
  final String username;
  final String location;
  final String email;

  const ProfilePage({
    Key? key,
    required this.username,
    required this.location,
    required this.email,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();

  static Future<void> show(
      BuildContext context, String username, String location, String email) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ProfilePage(
          username: username,
          location: location,
          email: email,
        ),
      ),
    );
  }
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;
  bool isLoading = true;

  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;
  String accountType = "user";

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.username);
    _emailController = TextEditingController(text: widget.email);
    _locationController = TextEditingController(text: widget.location);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('username') ?? widget.username;
      _emailController.text = prefs.getString('email') ?? widget.email;
      _locationController.text = prefs.getString('location') ?? widget.location;
      accountType = prefs.getString('account_type') ?? "user";
      isLoading = false;
    });
  }

  Future<void> _updateProfile() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/users/update-profile/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _usernameController.text.trim(),
          "email": _emailController.text.trim(),
          "location": _locationController.text.trim(),
          "account_type": accountType,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        if (responseData["user"] != null) {
          final user = responseData["user"];
          await prefs.setString('username', user["username"]);
          await prefs.setString('email', user["email"]);
          await prefs.setString('location', user["location"]);
          await prefs.setString('account_type', user["account_type"]);

          setState(() {
            _usernameController.text = user["username"];
            _emailController.text = user["email"];
            _locationController.text = user["location"];
            accountType = user["account_type"];
          });
        } else {
          await prefs.setString('username', _usernameController.text);
          await prefs.setString('email', _emailController.text);
          await prefs.setString('location', _locationController.text);
          await prefs.setString('account_type', accountType);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Profile updated successfully!")),
        );

        if (_emailController.text.trim() != widget.email.trim()) {
          await _showEmailVerificationDialog(context, _emailController.text.trim());
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed: ${responseData['error'] ?? response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    } finally {
      setState(() {
        isEditing = false;
        isLoading = false;
      });
    }
  }

  Future<void> _showEmailVerificationDialog(BuildContext context, String email) async {
    final TextEditingController _codeController = TextEditingController();
    bool isVerifying = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Email Verification",
                style: TextStyle(color: darkRed, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "A verification code has been sent to:\n$email",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Enter Verification Code",
                      prefixIcon: Icon(Icons.lock_outline, color: darkRed),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  isVerifying
                      ? const CircularProgressIndicator(color: darkRed)
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final code = _codeController.text.trim();
                            if (code.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter the code.")),
                              );
                              return;
                            }

                            setState(() => isVerifying = true);
                            try {
                              final verifyResponse = await http.post(
                                Uri.parse("$baseUrl/api/users/confirm-email/"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({"email": email, "code": code}),
                              );

                              if (verifyResponse.statusCode == 200) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("✅ Email verified successfully!")),
                                );
                              } else {
                                final data = jsonDecode(verifyResponse.body);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("❌ ${data['error'] ?? 'Invalid code.'}"),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("⚠️ Error verifying: $e")),
                              );
                            } finally {
                              setState(() => isVerifying = false);
                            }
                          },
                          child: const Text("Verify", style: TextStyle(color: Colors.white)),
                        ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ResQGoAuthPage()),
        (route) => false,
      );
    }
  }

  void _openHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Need Help?", style: TextStyle(color: darkRed)),
        content: const Text(
          "For any issues or emergencies:\n\n"
          "📧 support@resqgo.com\n📞 +91 9562171169",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: darkRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      clipBehavior: Clip.hardEdge,
      child: Container(
        color: const Color(0xFFF8F8F8),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: darkRed))
            : ListView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                children: [
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: darkRed.withOpacity(0.9),
                          child: const Icon(Icons.person, size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _usernameController.text,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: darkRed),
                        ),
                        Text(
                          accountType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildProfileTile(
                              icon: Icons.person_outline,
                              label: "Username",
                              controller: _usernameController),
                          const Divider(),
                          _buildProfileTile(
                              icon: Icons.email_outlined,
                              label: "Email",
                              controller: _emailController),
                          const Divider(),
                          _buildProfileTile(
                              icon: Icons.location_on_outlined,
                              label: "Location",
                              controller: _locationController),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  ElevatedButton.icon(
                    onPressed:
                        isEditing ? _updateProfile : () => setState(() => isEditing = true),
                    icon: Icon(isEditing ? Icons.save : Icons.edit),
                    label: Text(isEditing ? "Save Changes" : "Edit Profile"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openHelp,
                    icon: const Icon(Icons.help_outline),
                    label: const Text("Help & Support"),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: darkRed),
                      foregroundColor: darkRed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.black87),
                    label: const Text("Logout",
                        style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String label,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Icon(icon, color: darkRed, size: 26),
        const SizedBox(width: 15),
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: !isEditing,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: darkRed),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
