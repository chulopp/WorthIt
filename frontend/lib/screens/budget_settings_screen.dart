import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/snackbar_helper.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = numbers.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({Key? key}) : super(key: key);

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    final budget = prefs.getInt('monthly_budget') ?? 0;
    if (budget > 0) {
      String budgetStr = budget.toString();
      String formatted = budgetStr.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      setState(() {
        _controller.text = formatted;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color textPrimary = Color(0xFF1E293B);
    const Color bgScaffold = Color(0xFFF8F9FA);

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: bgScaffold,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'budget.title'.tr(),
          style: GoogleFonts.bricolageGrotesque(
            color: textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'budget.monthly_limit'.tr(),
                style: GoogleFonts.bricolageGrotesque(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: GoogleFonts.bricolageGrotesque(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixText: "Rp ",
                  prefixStyle: GoogleFonts.bricolageGrotesque(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    String raw = _controller.text.replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    int budget = int.tryParse(raw) ?? 0;
                    await prefs.setInt('monthly_budget', budget);

                    if (!mounted) return;

                    final successMessage = 'budget_save_success'.tr();
                    SnackbarHelper.showTopSnackbar(context, successMessage);

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF304423),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'budget.save'.tr(),
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
