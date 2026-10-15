import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'common.dart';

class DriverInfoCard extends StatelessWidget {
  const DriverInfoCard({
    super.key,
    required this.driverName,
    required this.plate,
    required this.vehicleLabel,
    required this.rating,
    this.verified = true,
    this.eta,
  });

  final String driverName;
  final String plate;
  final String vehicleLabel;
  final double rating;
  final bool verified;
  final int? eta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              Avatar(size: 48, name: driverName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            driverName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.green,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$vehicleLabel · $plate',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        Text(' ${rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              if (eta != null)
                Column(
                  children: [
                    Text(
                      '$eta',
                      style: const TextStyle(
                        fontSize: 26,
                        color: AppColors.terracotta,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.trackingMinsAway,
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Chip(
      avatar: Icon(
        Icons.verified_rounded,
        color: AppColors.green,
        size: small ? 14 : 16,
      ),
      label: Text(
        l10n.driverVerifiedBadge,
        style: TextStyle(fontSize: small ? 10 : 12),
      ),
      backgroundColor: const Color(0xFFE7F3E8),
      visualDensity: VisualDensity.compact,
    );
  }
}
