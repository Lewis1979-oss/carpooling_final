import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../services/theme_service.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../widgets/glass_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final double? amount;
  final String? rideId;
  final Function? onPaymentSuccess;

  const PaymentScreen({
    super.key,
    this.amount,
    this.rideId,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _payerPhoneController = TextEditingController();
  final _driverPhoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentService = PaymentService();
  final _authService = AuthService();
  final _rideService = RideService();
  
  bool _isRequesting = false;
  bool _isPolling = false;
  bool _isLoadingDriver = true;
  Timer? _timer;
  PaymentProvider _selectedProvider = PaymentProvider.mtn;

  static const Color mtnYellow = Color(0xFFFFCC00);
  static const Color mtnBlue = Color(0xFF003399);
  static const Color airtelRed = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    if (widget.amount != null) {
      _amountController.text = widget.amount!.toStringAsFixed(2);
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (userData?.phone != null && mounted) {
        setState(() => _payerPhoneController.text = userData!.phone!);
      }

      if (widget.rideId != null && widget.rideId!.isNotEmpty) {
        try {
          final ride = await _rideService.getRideById(widget.rideId!).first;
          final driverData = await _authService.getUserData(ride.driverId);
          if (driverData?.phone != null && mounted) {
            setState(() => _driverPhoneController.text = driverData!.phone!);
          }
        } catch (e) {
          debugPrint("Error fetching driver info: $e");
        }
      }
    }
    if (mounted) setState(() => _isLoadingDriver = false);
  }

  void _startPayment() async {
    final payerNum = _payerPhoneController.text.trim();
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);

    if (payerNum.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid payment details and amount')),
      );
      return;
    }

    setState(() => _isRequesting = true);

    // Initiating payment with rideId context if available
    String? referenceId = await _paymentService.requestToPay(
      phoneNumber: payerNum,
      amount: amount,
      currency: "ZMW",
      provider: _selectedProvider,
      rideId: widget.rideId,
    );

    setState(() => _isRequesting = false);

    if (referenceId != null) {
      if (_paymentService.useMockMode) {
        _showSimulatedPinPrompt(amount, referenceId);
      } else {
        _startPolling(referenceId);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initiate payment. Please check your network.')),
      );
    }
  }

  void _startPolling(String referenceId) {
    setState(() => _isPolling = true);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      String status = await _paymentService.checkPaymentStatus(referenceId, _selectedProvider);
      
      if (status == 'SUCCESSFUL') {
        timer.cancel();
        _handleSuccess();
      } else if (status == 'FAILED') {
        timer.cancel();
        _handleCancel("Payment failed or rejected.");
      }
    });

    Future.delayed(const Duration(minutes: 2), () {
      if (_timer != null && _timer!.isActive) {
        _timer!.cancel();
        _handleCancel("Transaction timed out.");
      }
    });
  }

  void _showSimulatedPinPrompt(double amount, String refId) {
    final TextEditingController pinController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), 
        title: const Text("Mobile Money", style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pay ZMW ${amount.toStringAsFixed(2)} to ZedPool? Enter PIN to confirm:",
              style: const TextStyle(color: Colors.black87, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.black, letterSpacing: 10, fontSize: 20),
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                isDense: true,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Mark as failed in DB on manual cancel
              await _paymentService.updateTransactionStatus(refId, "FAILED");
              _handleCancel("Transaction canceled");
            },
            child: const Text("CANCEL", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text.isNotEmpty) {
                Navigator.pop(context);
                _startPolling(refId); 
              }
            },
            child: const Text("SEND", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleCancel(String message) {
    if (mounted) {
      setState(() {
        _isPolling = false;
        _isRequesting = false;
      });
      _timer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleSuccess() {
    if (widget.onPaymentSuccess != null) {
      widget.onPaymentSuccess!();
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment Successful! Funds allocated to Driver.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _payerPhoneController.dispose();
    _driverPhoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final double appBarBottom = MediaQuery.of(context).padding.top + kToolbarHeight;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(
          _selectedProvider == PaymentProvider.mtn ? 'MTN MoMo Payment' : 'Airtel Money Payment', 
          style: TextStyle(color: _selectedProvider == PaymentProvider.mtn ? mtnBlue : Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: _selectedProvider == PaymentProvider.mtn ? mtnYellow.withOpacity(0.9) : airtelRed.withOpacity(0.9),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: _selectedProvider == PaymentProvider.mtn ? mtnBlue : Colors.white),
      ),
      body: _isLoadingDriver 
        ? const Center(child: CircularProgressIndicator(color: mtnYellow))
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildAmountHeader(isDark, appBarBottom),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _isPolling ? _buildPollingUI(isDark) : _buildPaymentForm(isDark),
                ),
                _buildSecurityFooter(),
              ],
            ),
          ),
    );
  }

  Widget _buildAmountHeader(bool isDark, double appBarBottom) {
    Color headerColor = _selectedProvider == PaymentProvider.mtn ? mtnYellow : airtelRed;
    Color textColor = _selectedProvider == PaymentProvider.mtn ? mtnBlue : Colors.white;

    return GlassContainer(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, appBarBottom + 20, 20, 40),
      borderRadius: 0,
      isDark: false,
      accentColor: headerColor,
      containerOpacity: 0.8,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: textColor.withOpacity(0.1)),
            child: Image.asset('assets/icon/app_icon.png', width: 45, height: 45),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('ZMW ', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 42, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
          Text('TAP AMOUNT TO EDIT', style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildPaymentForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('SELECT PROVIDER', 'Choose your mobile money wallet'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildProviderCard(
                provider: PaymentProvider.mtn,
                label: 'MTN MoMo',
                color: mtnYellow,
                isSelected: _selectedProvider == PaymentProvider.mtn,
                onTap: () => setState(() => _selectedProvider = PaymentProvider.mtn),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildProviderCard(
                provider: PaymentProvider.airtel,
                label: 'Airtel Money',
                color: airtelRed,
                isSelected: _selectedProvider == PaymentProvider.airtel,
                onTap: () => setState(() => _selectedProvider = PaymentProvider.airtel),
                isDark: isDark,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        
        _buildSectionTitle('1. YOUR WALLET NUMBER', 'Money will be deducted from here'),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: _payerPhoneController,
          hint: 'Enter Payer Number',
          icon: Icons.account_balance_wallet_outlined,
          isDark: isDark,
        ),
        
        const SizedBox(height: 30),
        
        _buildSectionTitle('2. RECEIVING CONTEXT', 'Verification of Driver details'),
        const SizedBox(height: 12),
        _buildGlassTextField(
          controller: _driverPhoneController,
          hint: 'Driver Number',
          icon: Icons.delivery_dining_outlined,
          isDark: isDark,
        ),

        const SizedBox(height: 40),
        
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _isRequesting ? null : _startPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedProvider == PaymentProvider.mtn ? mtnYellow : airtelRed,
              foregroundColor: _selectedProvider == PaymentProvider.mtn ? mtnBlue : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 8,
            ),
            child: _isRequesting 
              ? CircularProgressIndicator(color: _selectedProvider == PaymentProvider.mtn ? mtnBlue : Colors.white)
              : const Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard({
    required PaymentProvider provider,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              provider == PaymentProvider.mtn ? Icons.phone_android : Icons.phone_iphone, 
              color: isSelected ? color : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
        Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildGlassTextField({required TextEditingController controller, required String hint, required IconData icon, required bool isDark}) {
    Color accentColor = _selectedProvider == PaymentProvider.mtn ? mtnYellow : airtelRed;
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 15,
      isDark: isDark,
      accentColor: accentColor,
      blur: 10,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: _selectedProvider == PaymentProvider.mtn ? mtnBlue : airtelRed),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPollingUI(bool isDark) {
    Color accentColor = _selectedProvider == PaymentProvider.mtn ? mtnYellow : airtelRed;
    return GlassContainer(
      isDark: isDark,
      borderRadius: 25,
      accentColor: accentColor,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.vibration, size: 80, color: accentColor),
          const SizedBox(height: 30),
          const Text('Processing Payment...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'We are verifying your transaction with the network. Please wait.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15),
          ),
          const SizedBox(height: 40),
          CircularProgressIndicator(color: accentColor),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () async {
              // Get current referenceId if needed, but here we can just reset
               _handleCancel("Transaction canceled");
            },
            child: const Text('Cancel Transaction', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text('SECURE ESCROW PAYMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: 0.5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_selectedProvider == PaymentProvider.mtn ? 'MTN MoMo' : 'Airtel Money', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.lock, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                const Text('ZedPool Secure', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
