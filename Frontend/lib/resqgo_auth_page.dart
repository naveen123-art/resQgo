// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';

import 'resqgo_home_page.dart';
import 'service_provider_home_page.dart';

enum AccountType { user, serviceProvider }

class ResQGoAuthPage extends StatefulWidget {
  const ResQGoAuthPage({Key? key}) : super(key: key);

  @override
  _ResQGoAuthPageState createState() => _ResQGoAuthPageState();
}

class _ResQGoAuthPageState extends State<ResQGoAuthPage> {
  bool isLogin = true;
  bool isLoading = false;

  final _formKey = GlobalKey<FormState>();
  String email = '', username = '';
  AccountType selectedType = AccountType.user;
  String baseUrl = '';

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final String apiPrefix = '/api/users';

  bool loginValidated = false;
  bool signupValidated = false;

  @override
  void initState() {
    super.initState();
    setBaseUrl();
  }

  void setBaseUrl() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String url = '';

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      url = !androidInfo.isPhysicalDevice
          ? 'http://10.0.2.2:8080'
          : 'http://10.95.236.185:8080';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      url = !iosInfo.isPhysicalDevice
          ? 'http://localhost:8080'
          : 'http://10.95.236.185:8080';
    }

    print('🌐 Flutter backend URL: $url');
    setState(() => baseUrl = url);
  }

  Future<Map<String, dynamic>> postJson(Uri url, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final decoded = jsonDecode(response.body);
        print('⚠️ Backend error response: ${response.body}');
        return {"error": decoded["error"] ?? response.body};
      }
    } on SocketException {
      return {"error": "Failed to connect: No internet or server unreachable."};
    } on TimeoutException {
      return {"error": "Request timed out. Check server or network."};
    } catch (e) {
      print('❌ Exception in postJson: $e');
      return {"error": "Failed to connect to server. Check backend URL or network."};
    }
  }

  Future<void> submit() async {
    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Backend URL not initialized")));
      return;
    }

    if (isLogin && loginValidated) {
      print('✅ Login already validated — skipping revalidation.');
      return;
    } else if (!isLogin && signupValidated) {
      print('✅ Signup already validated — skipping revalidation.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);

    final url = isLogin
        ? Uri.parse('$baseUrl$apiPrefix/login/')
        : Uri.parse('$baseUrl$apiPrefix/signup/');

    final body = isLogin
        ? {
            "username": username,
            "password": _passwordController.text,
            "account_type":
                selectedType == AccountType.user ? "user" : "service_provider",
          }
        : {
            "username": username,
            "email": email,
            "password": _passwordController.text,
            "confirm_password": _confirmPasswordController.text,
            "account_type":
                selectedType == AccountType.user ? "user" : "service_provider",
          };

    final data = await postJson(url, body);

    if (data.containsKey("error")) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data["error"])));
      setState(() => isLoading = false);
      return;
    }

    if (isLogin) {
      loginValidated = true;
    } else {
      signupValidated = true;
    }

    if (!isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Signup successful! Check your email for confirmation code.")));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmEmailPage(
              email: email, baseUrl: baseUrl, apiPrefix: apiPrefix),
        ),
      );
    } else {
      await _loginSuccess(username);
    }

    setState(() => isLoading = false);
  }

  Future<void> _loginSuccess(String username) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final profileResponse =
          await http.get(Uri.parse('$baseUrl$apiPrefix/profile/$username/')).timeout(const Duration(seconds: 10));

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        await prefs.setString('username', profileData['username'] ?? username);
        await prefs.setString('account_type', profileData['account_type'] ?? 'user');
        await prefs.setString('email', profileData['email'] ?? '');

        if (profileData['account_type'] == 'service_provider') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ServiceProviderHomePage(username: profileData['username']),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResQGoHomePage(
                username: profileData['username'],
                accountType: profileData['account_type'] ?? 'user',
                location: '',
              ),
            ),
          );
        }
      } else {
        print('⚠️ Failed to fetch profile: ${profileResponse.body}');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to fetch profile data")));
      }
    } on SocketException {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No internet or server unreachable")));
    } on TimeoutException {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Request timed out. Try again.")));
    } catch (e) {
      print('❌ Exception in _loginSuccess: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to connect to server")));
    }
  }

  void forgotPasswordFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(baseUrl: baseUrl, apiPrefix: apiPrefix),
      ),
    );
  }

  String? usernameValidator(String? val) {
    if (val == null || val.isEmpty) return 'Enter username';
    final regex = RegExp(r'^[a-zA-Z\s]+$');
    if (!regex.hasMatch(val)) return 'Only letters and spaces allowed';
    return null;
  }

  String? passwordValidator(String? val) {
    if (val == null || val.length < 6) return 'Min 6 characters';
    return null;
  }

  String? emailValidator(String? val) {
  if (val == null || val.isEmpty) return 'Enter email';
  
  // Only allow Gmail addresses
  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
  
  if (!regex.hasMatch(val.trim())) {
    return 'enter valid email';
  }
  return null;
}


  @override
  Widget build(BuildContext context) {
    const darkRed = Color(0xFF8B0000);

    if (baseUrl.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: darkRed)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // App logo
                  Image.asset('assets/my_logo.png', height: 100),
                  const SizedBox(height: 10),
                  Text('ResQgo',
                      style: TextStyle(
                          color: darkRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 25),

                  // Beautiful rounded container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onSaved: (val) => username = val ?? '',
                          validator: usernameValidator,
                        ),
                        if (!isLogin)
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            onSaved: (val) => email = val ?? '',
                            validator: emailValidator,
                          ),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          validator: passwordValidator,
                        ),
                        if (!isLogin)
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (val) => val == _passwordController.text
                                ? null
                                : 'Passwords do not match',
                          ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Radio<AccountType>(
                              value: AccountType.user,
                              groupValue: selectedType,
                              onChanged: (val) => setState(() => selectedType = val!),
                              activeColor: darkRed,
                            ),
                            const Text('User'),
                            Radio<AccountType>(
                              value: AccountType.serviceProvider,
                              groupValue: selectedType,
                              onChanged: (val) => setState(() => selectedType = val!),
                              activeColor: darkRed,
                            ),
                            const Text('Service Provider'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkRed,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: isLoading ? null : submit,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(isLogin ? 'Login' : 'Sign Up',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 10),
                        if (isLogin)
                          TextButton(
                            onPressed: forgotPasswordFlow,
                            child: const Text('Forgot Password?',
                                style: TextStyle(color: darkRed)),
                          ),
                        TextButton(
                          onPressed: () => setState(() => isLogin = !isLogin),
                          child: Text(
                            isLogin
                                ? "Don't have an account? Sign Up"
                                : "Already have an account? Login",
                            style: const TextStyle(color: darkRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- EMAIL CONFIRMATION ----------------
class ConfirmEmailPage extends StatefulWidget {
  final String email;
  final String baseUrl;
  final String apiPrefix;

  const ConfirmEmailPage(
      {Key? key,
      required this.email,
      required this.baseUrl,
      required this.apiPrefix})
      : super(key: key);

  @override
  _ConfirmEmailPageState createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  final TextEditingController codeController = TextEditingController();
  bool isLoading = false;

  Future<Map<String, dynamic>> postJson(Uri url, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final decoded = jsonDecode(response.body);
        return {"error": decoded["error"] ?? response.body};
      }
    } on SocketException {
      return {"error": "No internet or server unreachable"};
    } on TimeoutException {
      return {"error": "Request timed out. Check server or network."};
    } catch (e) {
      return {"error": "Failed to connect to server"};
    }
  }

  void confirmEmail() async {
    if (codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Enter the confirmation code")));
      return;
    }

    setState(() => isLoading = true);
    final data = await postJson(
      Uri.parse('${widget.baseUrl}${widget.apiPrefix}/confirm-email/'),
      {"email": widget.email, "code": codeController.text.trim()},
    );
    setState(() => isLoading = false);

    if (data.containsKey("error")) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data["error"])));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Email confirmed!")));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ResQGoAuthPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Email"), backgroundColor: Color(0xFF8B0000)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Enter the confirmation code sent to ${widget.email}."),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Confirmation Code'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : confirmEmail,
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8B0000)),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Confirm Email"),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------- FORGOT PASSWORD ----------------
class ForgotPasswordPage extends StatefulWidget {
  final String baseUrl;
  final String apiPrefix;
  const ForgotPasswordPage(
      {Key? key, required this.baseUrl, required this.apiPrefix})
      : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  bool codeSent = false;
  bool isLoading = false;

  Future<Map<String, dynamic>> postJson(Uri url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body));
      return jsonDecode(response.body);
    } catch (e) {
      return {"error": "Failed to connect to server"};
    }
  }

  void requestCode() async {
    setState(() => isLoading = true);
    final data = await postJson(
        Uri.parse('${widget.baseUrl}${widget.apiPrefix}/request-reset-password/'),
        {"email": emailController.text.trim()});
    setState(() => isLoading = false);

    if (data.containsKey("error")) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data["error"])));
    } else {
      setState(() => codeSent = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Code sent to email")));
    }
  }

  void resetPassword() async {
    setState(() => isLoading = true);
    final data = await postJson(
        Uri.parse('${widget.baseUrl}${widget.apiPrefix}/reset-password/'),
        {
          "email": emailController.text.trim(),
          "code": codeController.text.trim(),
          "new_password": newPasswordController.text.trim(),
        });
    setState(() => isLoading = false);

    if (data.containsKey("error")) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data["error"])));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Password reset successful. Please login.")));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Reset Password"), backgroundColor: Color(0xFF8B0000)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            if (codeSent) ...[
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Reset Code')),
              TextField(controller: newPasswordController, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : (codeSent ? resetPassword : requestCode),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8B0000)),
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(codeSent ? "Reset Password" : "Send Code"),
            )
          ],
        ),
      ),
    );
  }
}
