import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  bool _isSaving = false;

  final _upiCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _cardNameCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  Future<void> _loadPaymentData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final payment = data['payment'] as Map<String, dynamic>? ?? {};
    setState(() {
      _upiCtrl.text = payment['upiId'] ?? '';
      _bankNameCtrl.text = payment['bankName'] ?? '';
      _accountNumberCtrl.text = payment['accountNumber'] ?? '';
      _ifscCtrl.text = payment['ifscCode'] ?? '';
      _accountHolderCtrl.text = payment['accountHolder'] ?? '';
      _cardNameCtrl.text = payment['cardName'] ?? '';
      _cardNumberCtrl.text = payment['cardLastFour'] ?? '';
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'payment': {
          'upiId': _upiCtrl.text.trim(),
          'bankName': _bankNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'ifscCode': _ifscCtrl.text.trim().toUpperCase(),
          'accountHolder': _accountHolderCtrl.text.trim(),
          'cardName': _cardNameCtrl.text.trim(),
          'cardLastFour': _cardNumberCtrl.text.trim(),
        }
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment settings saved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCtrl.dispose();
    _accountHolderCtrl.dispose();
    _cardNameCtrl.dispose();
    _cardNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFB71C1C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment & Bank Settings',
            style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB71C1C)))
                : const Text('Save',
                    style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFF7B0000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.white70, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Secure & Encrypted',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Your payment details are stored securely.',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _sectionLabel('UPI'),
            _buildCard([
              _buildField(
                controller: _upiCtrl,
                label: 'UPI ID',
                icon: Icons.account_balance_wallet_outlined,
                hint: 'yourname@upi',
                keyboardType: TextInputType.emailAddress,
              ),
            ]),

            _sectionLabel('Bank Account'),
            _buildCard([
              _buildField(
                controller: _accountHolderCtrl,
                label: 'Account Holder Name',
                icon: Icons.person_outline_rounded,
                hint: 'Full name as per bank',
              ),
              _divider(),
              _buildField(
                controller: _bankNameCtrl,
                label: 'Bank Name',
                icon: Icons.account_balance_outlined,
                hint: 'e.g. State Bank of India',
              ),
              _divider(),
              _buildField(
                controller: _accountNumberCtrl,
                label: 'Account Number',
                icon: Icons.numbers_rounded,
                hint: 'Enter account number',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(18)],
              ),
              _divider(),
              _buildField(
                controller: _ifscCtrl,
                label: 'IFSC Code',
                icon: Icons.tag_rounded,
                hint: 'e.g. SBIN0001234',
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(11),
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                ],
              ),
            ]),

            _sectionLabel('Card (Optional)'),
            _buildCard([
              _buildField(
                controller: _cardNameCtrl,
                label: 'Cardholder Name',
                icon: Icons.credit_card_outlined,
                hint: 'Name on card',
              ),
              _divider(),
              _buildField(
                controller: _cardNumberCtrl,
                label: 'Last 4 Digits',
                icon: Icons.dialpad_rounded,
                hint: 'XXXX',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              ),
            ]),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Payment Info',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB71C1C), letterSpacing: 0.5)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 48);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF0A500), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 15, color: Color(0xFF5C4033)),
            ),
          ),
        ],
      ),
    );
  }
}
