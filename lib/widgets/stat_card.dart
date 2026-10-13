import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
    this.iconText,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Color color;
  final String? iconText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.18),
                      color.withOpacity(0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: iconText == null
                      ? Icon(Icons.insights_rounded, color: color, size: 20)
                      : Text(
                          iconText!,
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const Spacer(),
              Container(
                width: 34,
                height: 5,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
