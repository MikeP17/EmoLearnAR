import 'package:flutter/material.dart';

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = const Color(0xFF2563EB),
    this.minimal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(minimal ? 0.72 : 0.88),
      borderRadius: BorderRadius.circular(minimal ? 28 : 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(minimal ? 28 : 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(minimal ? 20 : 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(minimal ? 28 : 24),
            border: Border.all(
              color: minimal
                  ? Colors.white.withOpacity(0.74)
                  : accent.withOpacity(0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(
                  minimal ? 0.045 : 0.05,
                ),
                blurRadius: minimal ? 26 : 22,
                offset: Offset(0, minimal ? 16 : 12),
              ),
            ],
          ),
          child: minimal
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withOpacity(0.16),
                            accent.withOpacity(0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF0B1120),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0B1120),
                                ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: const Color(0xFF64748B),
                                    height: 1.28,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: accent,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
