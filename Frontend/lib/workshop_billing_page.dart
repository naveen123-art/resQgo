import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resqgo_app/workshops_page.dart';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = 'http://10.95.236.185:8080/api/services/';
const String upiId = "naveenksamz123@okaxis"; // Replace with your UPI ID

class WorkshopBillingPage extends StatefulWidget {
  final Workshop workshop;

  const WorkshopBillingPage({Key? key, required this.workshop})
      : super(key: key);

  @override
  State<WorkshopBillingPage> createState() => _WorkshopBillingPageState();
}

class _WorkshopBillingPageState extends State<WorkshopBillingPage> {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;

  /// 🔹 Initiates payment using UPI
  Future<void> _makePayment(BuildContext context) async {
    final amount = _amountController.text.trim();

    if (amount.isEmpty || double.tryParse(amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter a valid amount.")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final String payeeName = widget.workshop.name;
    const String transactionNote = "Vehicle Service Payment";

    final Uri upiUri = Uri.parse(
      "upi://pay?pa=$upiId&pn=$payeeName&tn=$transactionNote&am=$amount&cu=INR",
    );

    try {
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Redirecting to UPI app (GPay, PhonePe, etc.)"),
          ),
        );

        // Wait for the user to return
        await Future.delayed(const Duration(seconds: 7));

        // After returning, confirm payment manually
        _showPaymentConfirmationDialog(amount);
      } else {
        _showStatusDialog(
          title: " No UPI App Found",
          message:
              "Please install Google Pay, PhonePe, or Paytm to proceed with payment.",
          color: Colors.redAccent,
        );
      }
    } catch (e) {
      await _savePaymentToBackend(amount, "FAILED");
      _showStatusDialog(
        title: " Payment Failed",
        message: "An unexpected error occurred.\nError: $e",
        color: Colors.redAccent,
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 🔹 Confirm payment success or cancellation
  void _showPaymentConfirmationDialog(String amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Payment"),
        content: const Text(
          "Did the payment complete successfully in your UPI app?",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _savePaymentToBackend(amount, "CANCELLED");
              _showStatusDialog(
                title: " Payment Cancelled",
                message: "Payment Cancelled.",
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

  /// 🔹 Collect feedback and rating after payment success
  void _showFeedbackDialog(String amount) {
    final TextEditingController feedbackController = TextEditingController();
    double rating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Rate Your Experience"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please rate the service provider:"),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: "Write your feedback (optional)",
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
                  await _markJobAsDone();
                },
                child: const Text("Skip"),
              ),
              TextButton(
                onPressed: () async {
                  if (rating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("⚠️ Please select a rating before submitting.")),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _saveFeedbackToBackend(rating, feedbackController.text);
                  await _markJobAsDone();

                  _showStatusDialog(
                    title: "Thank You!",
                    message:
                        "Your payment of ₹$amount and feedback were submitted successfully.",
                    color: Colors.green,
                  );

                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted)
                    Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text("Submit"),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 💾 Save payment details to backend
  Future<void> _savePaymentToBackend(String amount, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'guest_user';

      final response = await http.post(
        Uri.parse("${baseUrl}payments/save/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "mechanic_name": widget.workshop.name,
          "upi_id": upiId,
          "amount": amount,
          "transaction_status": status,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Payment ($status) saved to backend successfully.");
      } else {
        debugPrint(" Failed to save payment: ${response.body}");
      }
    } catch (e) {
      debugPrint(" Error saving payment: $e");
    }
  }

  /// 💬 Save user feedback and rating
  Future<void> _saveFeedbackToBackend(double rating, String feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'guest_user';

      final response = await http.post(
        Uri.parse("${baseUrl}feedback/submit/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "mechanic_name": widget.workshop.name,
          "rating": rating,
          "feedback": feedback,
          "timestamp": DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("Feedback saved successfully.");
      } else {
        debugPrint(" Failed to save feedback: ${response.body}");
      }
    } catch (e) {
      debugPrint(" Error saving feedback: $e");
    }
  }

  /// ✅ Mark the job as completed for the service provider
  Future<void> _markJobAsDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'guest_user';

      final response = await http.post(
        Uri.parse("${baseUrl}jobs/mark_done/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "mechanic_name": widget.workshop.name,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("Job marked as done successfully.");
      } else {
        debugPrint("Failed to mark job as done: ${response.body}");
      }
    } catch (e) {
      debugPrint(" Error marking job done: $e");
    }
  }

  /// 🔹 Generic status dialog
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
                "Workshop: ${widget.workshop.name}",
                style: TextStyle(
                  fontSize: size.width * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Phone: ${widget.workshop.phone}",
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
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Payment cancelled manually "),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text("Cancel"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            minimumSize: const Size(double.infinity, 50),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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
