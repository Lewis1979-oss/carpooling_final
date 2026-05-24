import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';

class UserManualScreen extends StatelessWidget {
  const UserManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return GlassScaffold(
      appBar: AppBar(
        title: const Text('User Manual', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: activeGold),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            _buildHeader("Welcome to ZedPool", activeGold),
            _buildText("ZedPool is a premium carpooling platform designed to make your daily commute safer, cheaper, and more comfortable. This guide will help you master all the features of the app."),
            
            _buildSection("1. Finding & Booking a Ride", activeGold, [
              "Search: Use the search bar on the 'Search' tab to find rides by destination.",
              "Filter: Browse through available premium listings, checking for driver ratings and comfort options like A/C or Music.",
              "Request: Tap 'Request to Join' on a ride that suits you. The driver will receive a notification to approve your request.",
              "Approval: Once approved, you'll be notified and the ride will appear in your 'Joined' history."
            ]),

            _buildSection("2. Sharing/Posting a Ride", activeGold, [
              "Start: Go to the 'Home' tab and tap the '+' button or 'Post a Ride'.",
              "Details: Set your pickup, destination, price per seat, and available seats.",
              "Preferences: Toggle options like A/C, Smoking, or Music to let passengers know what to expect.",
              "Manage: View pending requests in 'My Rides' > 'Driving'. You can approve or decline users there."
            ]),

            _buildSection("3. Communication (Chat)", activeGold, [
              "Group Chat: Every ride has a group chat for all confirmed participants.",
              "Private Chat: You can message a driver directly from the Ride Details screen.",
              "Features: Send text, images, or voice messages. You can also react to messages with emojis.",
              "Last Seen: Check the top of the chat to see if the other person is online or when they were last active."
            ]),

            _buildSection("4. Ride History & Tracking", activeGold, [
              "History: Access 'My Rides' to see upcoming, ongoing, and completed trips.",
              "Live Tracking: Once a ride starts, tap 'Track' to see the real-time location of the vehicle on the map.",
              "Status: Rides move through 'Scheduled', 'Ongoing', and 'Completed' statuses automatically."
            ]),

            _buildSection("5. Safety & SOS", activeGold, [
              "SOS Button: Located at the top right of the Home and Chat screens. Tap this in an emergency to alert ZedPool Admins and dial emergency services immediately.",
              "Reporting: If you encounter an issue during a ride, use the 'Report' button in Ride Details to send a safety report to our team.",
              "Verified Users: Look for the blue tick next to names. This indicates the user has submitted valid ID for verification."
            ]),

            _buildSection("6. Profile & Verification", activeGold, [
              "Update Info: Go to 'Profile' > 'Account Settings' to change your name, phone, or vehicle details.",
              "Badges: Earn badges like 'Super Driver' by maintaining high ratings and completing many rides.",
              "ZedPoints: Accumulate points for every ride you take. These points can be used for future rewards."
            ]),

            _buildSection("7. Payments", activeGold, [
              "Wallet: View your current balance in the 'Payments' screen.",
              "Top Up: Add funds to your wallet using integrated mobile money services.",
              "Automatic: Payments are processed securely within the app once a ride is successfully completed."
            ]),

            _buildSection("8. Personalization", activeGold, [
              "Themes: Use the 'Appearance' menu to switch between dark and light modes.",
              "Accents: Choose from Gold, Emerald, Sapphire, and other premium accent colors to make the app yours.",
              "Font Size: Adjust text size in Account Settings for better readability."
            ]),

            const SizedBox(height: 50),
            Center(
              child: Text(
                "Version 1.0.0 • Premium ZedPool Experience",
                style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: gold, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSection(String title, Color gold, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(title, style: TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...points.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("• ", style: TextStyle(color: gold, fontWeight: FontWeight.bold)),
              Expanded(child: Text(p, style: const TextStyle(fontSize: 14, height: 1.5))),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.grey),
    );
  }
}
