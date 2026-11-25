import 'package:flutter/material.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_card.dart';

/// Kartu status paket langganan SmartFi
class SubscriptionInfoCard extends StatelessWidget {
  const SubscriptionInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final mutedCol = NeoColors.mutedText(context);
    final borderCol = NeoColors.border(context);
    final secondaryCol = NeoColors.surfaceSecondary(context);

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
                  color: NeoColors.yellowAccent,
                  border: Border.all(color: NeoColors.black, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: const Icon(Icons.workspace_premium, color: NeoColors.black, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS LANGGANAN',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'INFORMASI PAKET AKUN ANDA',
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: secondaryCol,
              border: Border.all(color: borderCol, width: 2),
              boxShadow: NeoColors.hardShadow(offset: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SMARTFI PRO ACCESS',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Semua fitur terbuka & aktif selamanya',
                        style: TextStyle(fontSize: 10, color: mutedCol),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const NeoBadge(
                  text: 'BEBAS',
                  backgroundColor: NeoColors.successGreenLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
