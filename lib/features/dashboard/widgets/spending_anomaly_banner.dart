import 'package:flutter/material.dart';

import '../../../core/services/spending_anomaly_detector.dart';
import '../../../core/theme/neo_colors.dart';
import '../../../shared/widgets/neo_badge.dart';
import '../../../shared/widgets/neo_button.dart';
import '../../../shared/widgets/neo_card.dart';

/// Banner peringatan Neobrutalism ketika pengeluaran hari ini terdeteksi anomali
class SpendingAnomalyBanner extends StatelessWidget {
  final SpendingAnomalyResult anomaly;
  final VoidCallback? onAskMentor;

  const SpendingAnomalyBanner({
    super.key,
    required this.anomaly,
    this.onAskMentor,
  });

  @override
  Widget build(BuildContext context) {
    if (!anomaly.isAnomaly) return const SizedBox.shrink();

    final isCritical = anomaly.severity == AnomalySeverity.critical;
    final bgColor = isCritical ? NeoColors.dangerRedLight : NeoColors.yellowAccent;
    final badgeBg = isCritical ? NeoColors.dangerRed : NeoColors.white;
    final badgeTextCol = isCritical ? NeoColors.textLight : NeoColors.textDark;

    return NeoCard(
      backgroundColor: bgColor,
      borderColor: NeoColors.black,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeoColors.white,
                  border: Border.all(color: NeoColors.black, width: 2),
                  boxShadow: NeoColors.hardShadow(offset: 2),
                ),
                child: Icon(
                  isCritical ? Icons.bolt : Icons.warning_amber_rounded,
                  color: NeoColors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeoBadge(
                      text: isCritical ? 'ANOMALI KRITIS' : 'ANOMALI HARIAN',
                      backgroundColor: badgeBg,
                      textColor: badgeTextCol,
                      fontSize: 9,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      anomaly.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: NeoColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            anomaly.message,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: NeoColors.textDark,
            ),
          ),
          if (onAskMentor != null) ...[
            const SizedBox(height: 12),
            NeoButton(
              text: 'Evaluasi Bersama Mentor AI',
              backgroundColor: NeoColors.white,
              textColor: NeoColors.textDark,
              shadowOffset: 3,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              icon: const Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: NeoColors.black,
              ),
              onPressed: onAskMentor,
            ),
          ],
        ],
      ),
    );
  }
}
