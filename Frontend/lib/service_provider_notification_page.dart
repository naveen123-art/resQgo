import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const Color darkRed = Color(0xFF8B0000);
const String baseUrl = "http://10.95.236.185:8080";

class ServiceProviderNotificationPage extends StatefulWidget {
  final String username;

  const ServiceProviderNotificationPage({Key? key, required this.username})
      : super(key: key);

  @override
  State<ServiceProviderNotificationPage> createState() =>
      _ServiceProviderNotificationPageState();
}

class _ServiceProviderNotificationPageState
    extends State<ServiceProviderNotificationPage> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  // ✅ Fetch notifications
  Future<void> fetchNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/services/notifications/${widget.username}/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          notifications = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        debugPrint("Failed to load notifications: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching notifications: $e");
    }
  }

  // ✅ Clear all notifications
  Future<void> clearNotifications() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/services/notifications/clear/${widget.username}/'),
      );

      if (response.statusCode == 200) {
        setState(() {
          notifications.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("All notifications cleared")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to clear notifications")),
        );
      }
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  // ✅ Delete single notification
  Future<void> deleteNotification(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/services/notifications/delete/$id/'),
      );

      if (response.statusCode == 200) {
        setState(() {
          notifications.removeWhere((n) => n['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to delete notification")),
        );
      }
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea( // ✅ Prevent bottom overflow
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Notifications", style: TextStyle(color: Colors.white)),
          backgroundColor: darkRed,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              onPressed: clearNotifications,
              tooltip: "Clear all notifications",
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: darkRed))
            : notifications.isEmpty
                ? const Center(
                    child: Text(
                      "No notifications yet.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12), // ✅ Prevent clipping
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.notifications_active,
                                color: darkRed),
                            title: Text(
                              notification['title'] ?? 'New Notification',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notification['message'] ??
                                    'You have a new update.'),
                                const SizedBox(height: 6),
                                Text(
                                  "Username: ${notification['sender_username'] ?? 'N/A'}",
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                                Text(
                                  "Phone: ${notification['sender_phone'] ?? 'N/A'}",
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: darkRed),
                                  onPressed: () =>
                                      deleteNotification(notification['id']),
                                  tooltip: "Delete this notification",
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
