import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final authService = context.read<AuthService>();
    final success = await authService.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else if (mounted && authService.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.error!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.dark, AppColors.primary],
            stops: [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SHAM STORES',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'بوابة مندوب التوصيل',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Form card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'تسجيل الدخول',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'أدخل بيانات حسابك للمتابعة',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                ),
                          ),
                          const SizedBox(height: 28),

                          // Email field
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              hintText: 'example@email.com',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.secondary),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                              if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.secondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.muted,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور';
                              if (v.length < 6) return 'كلمة المرور قصيرة جداً';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          // Login button
                          ElevatedButton(
                            onPressed: authService.isLoading ? null : _login,
                            child: authService.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: AppColors.dark,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, size: 18),
                                      SizedBox(width: 8),
                                      Text('تسجيل الدخول'),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 24),

                          // Info note
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.15),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.secondary, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'هذا التطبيق مخصص لمندوبي التوصيل المسجلين في شام ستور',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: AppColors.secondary,
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}
