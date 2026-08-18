import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'nearby_mechanics_page.dart';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = 'http://10.95.236.185:8080/api/services/';

class BillingPage extends StatefulWidget {
  final Mechanic mechanic;
  const BillingPage({Key? key, required this.mechanic}) : super(key: key);

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  double _rating = 0.0;
  final TextEditingController _feedbackController = TextEditingController();

  /// 🔹 Launch UPI payment and monitor result
  Future<void> _makePayment(BuildContext context) async {
    final amount = _amountController.text.trim();
    if (amount.isEmpty || double.tryParse(amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Please enter a valid amount")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    const String upiID = "naveenksamz123@okaxis"; // your real UPI ID
    final String payeeName = widget.mechanic.name;
    const String transactionNote = "Vehicle Service Payment";

    final Uri upiUri = Uri.parse(
      "upi://pay?pa=$upiID&pn=$payeeName&tn=$transactionNote&am=$amount&cu=INR",
    );

    try {
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Redirecting to UPI app (GPay, PhonePe, Paytm...)"),
          ),
        );

        // Simulate waiting for payment return
        await Future.delayed(const Duration(seconds: 6));

        _showPaymentConfirmationDialog(amount);
      } else {
        _showStatusDialog(
          title: " No UPI App Found",
          message: "Install Google Pay, PhonePe or Paytm to continue payment.",
          color: Colors.redAccent,
        );
      }
    } catch (e) {
      await _savePaymentToBackend(amount, "FAILED");
      _showStatusDialog(
        title: " Payment Failed",
        message: "Something went wrong.\nError: $e",
        color: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 🔹 Ask user if payment was successful or cancelled
  void _showPaymentConfirmationDialog(String amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Payment"),
        content: const Text(
            "Did the payment go through successfully in your UPI app?"),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _savePaymentToBackend(amount, "CANCELLED");
              _showStatusDialog(
                title: " Payment Cancelled",
                message:
                    "It seems you returned without completing the payment.",
                color: Colors.redAccent,
              );
            },
            child: const Text("No, Cancelled"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _savePaymentToBackend(amount, "SUCCESS");
              _showFeedbackDialog(amount);
            },
            child: const Text("Yes, Paid"),
          ),
        ],
      ),
    );
  }

  /// 🔹 Feedback + rating dialog with skip option
  void _showFeedbackDialog(String amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Rate & Feedback"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How satisfied are you with the service?"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 30,
                    ),
                    onPressed: () {
                      setStateDialog(() => _rating = index + 1.0);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _feedbackController,
                decoration: const InputDecoration(
                  labelText: "Leave a feedback (optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                _showStatusDialog(
                  title: "Feedback Skipped",
                  message: "Feedback not provided.",
                  color: Colors.orangeAccent,
                );
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("Skip"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _submitFeedback();
                _showStatusDialog(
                  title: "Thank You!",
                  message:
                      "Your payment of ₹$amount and feedback were submitted successfully.",
                  color: Colors.green,
                );
                await Future.delayed(const Duration(seconds: 2));
                if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Save payment record to backend
  Future<void> _savePaymentToBackend(String amount, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'guest_user';

      final response = await http.post(
        Uri.parse("${baseUrl}payments/save/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "mechanic_name": widget.mechanic.name,
          "upi_id": "naveenksamz123@okaxis",
          "amount": amount,
          "transaction_status": status,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(" Payment saved successfully ($status).");
      } else {
        debugPrint(" Backend error: ${response.body}");
      }
    } catch (e) {
      debugPrint(" Error saving payment: $e");
    }
  }

  /// 🔹 Submit feedback to backend
  Future<void> _submitFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'guest_user';

      final response = await http.post(
        Uri.parse("${baseUrl}feedback/submit/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "mechanic_name": widget.mechanic.name,
          "rating": _rating,
          "feedback_text": _feedbackController.text.trim(),
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(" Feedback submitted successfully.");
      } else {
        debugPrint(" Error submitting feedback: ${response.body}");
      }
    } catch (e) {
      debugPrint(" Feedback submission error: $e");
    }
  }

  /// 🔹 Show dialogs for result
  void _showStatusDialog({
    required String title,
    required String message,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: TextStyle(color: color)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Billing", style: TextStyle(color: Colors.white)),
        backgroundColor: darkRed,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(size.width * 0.05),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Mechanic: ${widget.mechanic.name}",
                style: TextStyle(
                  fontSize: size.width * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Phone: ${widget.mechanic.phone}",
                style: TextStyle(fontSize: size.width * 0.04),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Enter Amount (₹)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 30),
              _isProcessing
                  ? const Center(child: CircularProgressIndicator(color: darkRed))
                  : Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _makePayment(context),
                          icon: const Icon(Icons.payment),
                          label: const Text("Pay via GPay / UPI"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size(double.infinity, 50),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Service cancelled"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text("Cancel"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            minimumSize: const Size(double.infinity, 50),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
