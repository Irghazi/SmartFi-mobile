import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';
import '../../../shared/widgets/neo_input.dart';
import '../../auth/providers/auth_provider.dart';

/// Kartu pengaturan profil pengguna
class ProfileSettingsCard extends ConsumerStatefulWidget {
  const ProfileSettingsCard({super.key});

  @override
  ConsumerState<ProfileSettingsCard> createState() => _ProfileSettingsCardState();
}

class _ProfileSettingsCardState extends ConsumerState<ProfileSettingsCard> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isInit = false;
  String? _lastUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final user = ref.read(authStateProvider).asData?.value;
      if (user != null) {
        _lastUserId = user.id;
        _nameController.text = user.name;
        _emailController.text = user.email;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong.'),
          backgroundColor: NeoColors.warningYellow,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(name: newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: NeoColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: NeoColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      final user = next.asData?.value;
      if (user != null) {
        if (_lastUserId != user.id || _nameController.text.isEmpty) {
          _lastUserId = user.id;
          _nameController.text = user.name;
        }
        _emailController.text = user.email;
      }
    });

    final textCol = NeoColors.text(context);
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);

    return NeoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeoColors.headerBg(context),
                  border: Border.all(color: borderCol, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(Icons.person, color: textCol, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROFIL PENGGUNA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'INFORMASI DASAR AKUN ANDA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: mutedCol,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NeoInput(
            label: 'NAMA LENGKAP',
            controller: _nameController,
            hintText: 'Nama lengkap Anda',
          ),
          const SizedBox(height: 12),
          NeoInput(
            label: 'ALAMAT EMAIL (HANYA BACA)',
            controller: _emailController,
            enabled: false,
          ),
          const SizedBox(height: 16),
          NeoButton(
            text: _isLoading ? 'MENYIMPAN...' : 'SIMPAN PROFIL',
            backgroundColor: NeoColors.primaryBlue,
            textColor: NeoColors.white,
            onPressed: _isLoading ? null : _handleSave,
          ),
        ],
      ),
    );
  }
}
