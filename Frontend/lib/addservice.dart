import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color darkRed = Color(0xFF8B0000);

class AddServicePage extends StatefulWidget {
  final String username;

  const AddServicePage({Key? key, required this.username}) : super(key: key);

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  String name = '';
  String phone = '';
  String email = '';
  String? serviceType;
  String description = '';
  String place = '';

  final List<String> serviceTypes = [
    'Nearby Mechanic',
    'Workshop',
  ];

  Future<bool> verifyEmailCode(String email, String code) async {
    final url = Uri.parse("http://10.95.236.185:8080/api/services/confirm-service-email/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email.trim(), "code": code.trim()}),
    );

    print("Verification status: ${response.statusCode}");
    print("Verification body: ${response.body}");

    try {
      final data = jsonDecode(response.body);
      return data["success"] == true;
    } catch (e) {
      print("Decode error: $e");
      return false;
    }
  }

  Future<void> submitService() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);

    try {
      final url = Uri.parse("http://10.95.236.185:8080/api/services/add_service/");

      final body = {
        "username": widget.username,
        "email": email,
        "name": name,
        "phone": phone,
        "place": place,
        "description": description,
        "service_type": serviceType,
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print("Submit status: ${response.statusCode}");
      print("Submit body: ${response.body}");

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String? code = await showDialog<String>(
          context: context,
          builder: (context) {
            String inputCode = '';
            return AlertDialog(
              title: const Text("Enter Email Verification Code"),
              content: TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (val) => inputCode = val,
                decoration: const InputDecoration(hintText: "6-digit code"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, inputCode),
                  child: const Text("Verify"),
                ),
              ],
            );
          },
        );

        if (code == null || code.isEmpty) throw Exception("Verification cancelled");

        final verified = await verifyEmailCode(email, code);
        if (!verified) throw Exception("Invalid verification code");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${serviceType!} added and verified successfully!")),
        );

        _formKey.currentState!.reset();
        setState(() => serviceType = null);

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["error"] ?? "Failed to add service")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  String? nameValidator(String? val) {
    if (val == null || val.isEmpty) return 'Enter name';
    final regex = RegExp(r'^[a-zA-Z\s]+$');
    if (!regex.hasMatch(val)) return 'Name can only contain letters and spaces';
    return null;
  }

  String? phoneValidator(String? val) {
    if (val == null || val.isEmpty) return 'Enter phone';
    final regex = RegExp(r'^\d{10}$');
    if (!regex.hasMatch(val)) return  'Phone must be exactly 10 digits';
    return null;
  }

  // ✅ Improved Email Validator
  String? emailValidator(String? val) {
    if (val == null || val.isEmpty) return 'Enter email';

    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!regex.hasMatch(val.trim())) {
      return 'Enter a valid email (e.g., name@example.com)';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Service"),
        backgroundColor: darkRed,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  prefixIcon: const Icon(Icons.person_outline, color: darkRed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onSaved: (val) => name = val ?? '',
                validator: nameValidator,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email, color: darkRed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                keyboardType: TextInputType.emailAddress,
                onSaved: (val) => email = val?.trim() ?? '',
                validator: emailValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone, color: darkRed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                keyboardType: TextInputType.phone,
                onSaved: (val) => phone = val ?? '',
                validator: phoneValidator,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                  LengthLimitingTextInputFormatter(13),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: serviceType,
                decoration: InputDecoration(
                  labelText: 'Service Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: serviceTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (val) => setState(() => serviceType = val),
                validator: (val) => val == null || val.isEmpty ? 'Select service type' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description, color: darkRed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                maxLines: 3,
                onSaved: (val) => description = val ?? '',
                validator: (val) => val == null || val.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Place',
                  prefixIcon: const Icon(Icons.location_on, color: darkRed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onSaved: (val) => place = val ?? '',
                validator: (val) => val == null || val.isEmpty ? 'Enter place' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isLoading ? null : submitService,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Add Service",
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
