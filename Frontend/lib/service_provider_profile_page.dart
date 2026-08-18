// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import ' resqgo_auth_page.dart';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = "http://10.95.236.185:8080"; // change your IP if needed

class ServiceProviderProfilePage extends StatefulWidget {
  final String username;
  final String accountType;

  const ServiceProviderProfilePage({
    Key? key,
    required this.username,
    required this.accountType,
  }) : super(key: key);

  @override
  State<ServiceProviderProfilePage> createState() =>
      _ServiceProviderProfilePageState();
}

class _ServiceProviderProfilePageState
    extends State<ServiceProviderProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool isEditing = false;
  bool isVerifying = false;

  String name = '';
  String email = '';
  String phone = '';
  String verificationCode = '';

  @override
  void initState() {
    super.initState();
    fetchProfileData();
  }

  // ------------------- FETCH PROFILE -------------------
  Future<void> fetchProfileData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/profile/${widget.username}/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          name = data['username'] ?? '';
          email = data['email'] ?? '';
          phone = data['phone'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching profile: $e");
    }
  }

  // ------------------- REQUEST VERIFICATION CODE -------------------
  Future<void> requestEmailVerification() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/update_profile/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": widget.username,
          "email": email,
          "phone": phone,
        }),
      );

      if (response.statusCode == 200) {
        _showVerificationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Failed to send verification code")),
        );
      }
    } catch (e) {
      debugPrint("Verification error: $e");
    }
  }

  // ------------------- SHOW DIALOG -------------------
  void _showVerificationDialog() {
    verificationCode = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Email Verification"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the 6-digit code sent to your new email."),
              const SizedBox(height: 10),
              TextField(
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    labelText: "Verification Code",
                    counterText: '',
                    border: OutlineInputBorder()),
                onChanged: (value) => verificationCode = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: darkRed),
              onPressed: () async {
                Navigator.pop(context);
                await verifyEmailCode();
              },
              child: const Text("Verify"),
            ),
          ],
        );
      },
    );
  }

  // ------------------- VERIFY EMAIL CODE -------------------
  Future<void> verifyEmailCode() async {
    try {
      setState(() => isVerifying = true);

      final response = await http.post(
        Uri.parse('$baseUrl/api/users/verify_email_code/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": widget.username,
          "code": verificationCode,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Email verified & profile updated!")),
        );
        setState(() {
          isEditing = false;
        });
        fetchProfileData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Invalid verification code")),
        );
      }
    } catch (e) {
      debugPrint("Verification failed: $e");
    } finally {
      setState(() => isVerifying = false);
    }
  }

  // ------------------- UPDATE PROFILE -------------------
  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await requestEmailVerification();
  }

  // ------------------- LOGOUT FUNCTION -------------------
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ResQGoAuthPage()),
        (route) => false,
      );
    }
  }

  // ------------------- HELP DIALOG -------------------
  void showHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Help & Support"),
        content: const Text(
            "Edit your email or phone, then verify your new email via code before saving."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: darkRed,
        title: const Text("My Profile", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: showHelp,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: darkRed))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 25),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isEditing
                        ? _buildEditForm()
                        : _buildProfileView(context),
                  ),
                ],
              ),
            ),
    );
  }

  // ------------------- HEADER -------------------
  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [darkRed.withOpacity(0.9), Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, offset: const Offset(0, 3), blurRadius: 8)
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            name.isNotEmpty ? name : widget.username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.accountType.toUpperCase(),
            style: const TextStyle(
                fontSize: 14, color: Colors.white70, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  // ------------------- VIEW -------------------
  Widget _buildProfileView(BuildContext context) {
    return Column(
      key: const ValueKey(1),
      children: [
        _infoCard(Icons.email_outlined, "Email", email),
        const SizedBox(height: 12),
        _infoCard(Icons.phone, "Phone", phone),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: darkRed,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text("Edit Profile",
                style: TextStyle(color: Colors.white, fontSize: 18)),
            onPressed: () {
              setState(() => isEditing = true);
            },
          ),
        ),
      ],
    );
  }

  // ------------------- EDIT FORM -------------------
  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey(2),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField("Email", email, (val) => email = val),
          const SizedBox(height: 16),
          _buildTextField("Phone", phone, (val) => phone = val, isPhone: true),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text("Cancel",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: () {
                    setState(() => isEditing = false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text("Save",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: updateProfile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: darkRed, size: 28),
        title: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black54)),
        subtitle: Text(
          value.isNotEmpty ? value : "Not provided",
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSave,
      {bool isPhone = false}) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label == "Email" ? Icons.email_outlined : Icons.phone,
          color: darkRed,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return "Enter $label";
        if (isPhone && !RegExp(r'^[0-9]{10}$').hasMatch(val)) {
          return "Enter valid 10-digit phone number";
        }
        if (label == "Email" &&
            !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(val)) {
          return "Enter valid email address";
        }
        return null;
      },
      onSaved: (val) => onSave(val ?? ""),
    );
  }
}
