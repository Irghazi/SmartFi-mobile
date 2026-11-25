import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/blueprint_background.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isFormFilled =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.trim().isNotEmpty;

  Future<void> _handleRegister() async {
    final nameErr = Validators.validateRequired(_nameController.text, 'Nama lengkap');
    final emailErr = Validators.validateEmail(_emailController.text);
    final passErr = Validators.validatePassword(_passwordController.text);

    if (nameErr != null || emailErr != null || passErr != null) {
      setState(() {
        _nameError = nameErr;
        _emailError = emailErr;
        _passwordError = passErr;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await ref.read(authControllerProvider.notifier).register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);

    return Scaffold(
      body: BlueprintBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: NeoCard(
                  shadowOffset: 8.0,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Neobrutalism
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: NeoColors.surfaceLight,
                          border: Border.all(color: NeoColors.black, width: 4.0),
                          boxShadow: NeoColors.hardShadow(offset: 4.0),
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'BUAT AKUN BARU',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textCol,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ayo daftar dan kelola finansial Anda dengan cerdas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mutedCol,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Input Nama Lengkap
                      NeoInput(
                        label: 'Nama Lengkap',
                        hintText: 'Masukkan nama lengkap Anda',
                        controller: _nameController,
                        errorText: _nameError,
                        onChanged: (_) => setState(() => _nameError = null),
                      ),
                      const SizedBox(height: 16),

                      // Input Email
                      NeoInput(
                        label: 'Email',
                        hintText: 'Masukkan email aktif Anda',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: (_) => setState(() => _emailError = null),
                      ),
                      const SizedBox(height: 16),

                      // Input Kata Sandi
                      NeoInput(
                        label: 'Kata Sandi',
                        hintText: 'Minimal 6 karakter',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        errorText: _passwordError,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 20,
                            color: mutedCol,
                          ),
                        ),
                        onChanged: (_) => setState(() => _passwordError = null),
                      ),
                      const SizedBox(height: 16),

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: NeoColors.dangerRed,
                            border: Border.all(color: NeoColors.black, width: 2.0),
                            boxShadow: NeoColors.hardShadow(offset: 4.0),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: NeoColors.textLight,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tombol Daftar
                      NeoButton(
                        text: 'Daftar',
                        onPressed: (_isFormFilled && !_isLoading) ? _handleRegister : null,
                        isLoading: _isLoading,
                        variant: NeoButtonVariant.primary,
                      ),
                      const SizedBox(height: 24),

                      // Link Login
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Sudah punya akun? ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: textCol,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              'Masuk di sini',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: NeoColors.blueAccentText(context),
                                decoration: TextDecoration.underline,
                                decorationThickness: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

