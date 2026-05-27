import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../widgets/glass_widgets.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final gold = themeService.goldAccent;
    final bodyColor = isDark ? Colors.white : Colors.black87;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: gold, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to view history"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('payments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5), // Standard gap before header
                    _buildHeader(context, isDark, bodyColor),
                    Expanded(
                      child: docs.isEmpty 
                        ? _buildEmptyState(gold, isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 15, 20, 20), // 15px top padding as requested
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              return _buildPaymentCard(data, isDark, gold);
                            },
                          ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color bodyColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), // Bottom padding set to 0
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment History",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: bodyColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Transaction records",
            style: TextStyle(
              fontSize: 14,
              color: bodyColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> data, bool isDark, Color gold) {
    final amount = data['amount'] ?? 0.0;
    final status = data['status'] ?? 'PENDING';
    final provider = data['provider'] ?? 'mtn';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final ref = data['referenceId'] ?? 'N/A';

    final isSuccess = status == 'SUCCESSFUL';
    final isFailed = status == 'FAILED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        isDark: isDark,
        padding: const EdgeInsets.all(4),
        borderRadius: 20,
        accentColor: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: gold.withOpacity(0.1),
            child: Icon(
              provider == 'mtn' ? Icons.phone_android : Icons.phone_iphone,
              color: gold,
              size: 20,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSuccess ? 'Payment Received' : (isFailed ? 'Payment Failed' : 'Payment Pending'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'ZMW ${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: gold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ref: ${ref.toString().length > 8 ? ref.toString().substring(0, 8) : ref}...',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      DateFormat('MMM d, h:mm a').format(timestamp),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange)).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange)).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color gold, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: gold.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "No transactions yet",
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
