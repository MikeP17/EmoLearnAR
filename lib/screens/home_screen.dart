import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../routes/app_routes.dart';
import '../services/monitoring_provider.dart';
import '../widgets/action_tile.dart';
import '../widgets/gradient_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<_ClassSession> _sessions = [
    _ClassSession(
      name: 'TTTK4086 Project',
      time: '09:00 AM - 10:30 AM',
      accent: const Color(0xFF2563EB),
      icon: Icons.assignment_rounded,
    ),
    _ClassSession(
      name: 'TC2543 Machine Learning',
      time: '11:00 AM - 12:30 PM',
      accent: const Color(0xFF7C3AED),
      icon: Icons.memory_rounded,
    ),
    _ClassSession(
      name: 'TTTC3413 Robot Applications',
      time: '02:00 PM - 03:30 PM',
      accent: const Color(0xFF0891B2),
      icon: Icons.smart_toy_rounded,
    ),
  ];

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MonitoringProvider>().checkBackendHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _sessions[_selectedIndex];

    return GradientScaffold(
      child: ResponsivePage(
        maxWidth: 820,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;

            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: compact ? 10 : 22),
                      const _LogoMark(),
                      SizedBox(height: compact ? 18 : 26),
                      Text(
                        'EmoLearnAR',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  color: const Color(0xFF0B1120),
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'AI classroom engagement monitor',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      SizedBox(height: compact ? 24 : 34),
                      _ClassSessionPicker(
                        sessions: _sessions,
                        selectedIndex: _selectedIndex,
                        onSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onAddSession: _showAddSessionSheet,
                      ),
                      SizedBox(height: compact ? 22 : 30),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _PrimaryStartButton(
                          selected: selected,
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.monitoring,
                            arguments: {
                              'className': selected.name,
                              'classTime': selected.time,
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 20 : 30),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: const _BackendStatusPill(),
                      ),
                      SizedBox(height: compact ? 16 : 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ActionTile(
                          icon: Icons.summarize_rounded,
                          title: 'Session Summary',
                          subtitle: '',
                          accent: const Color(0xFF7C3AED),
                          minimal: true,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.summary,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddSessionSheet() async {
    final added = await showModalBottomSheet<_ClassSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddSessionSheet(),
    );

    if (added == null) return;
    setState(() {
      _sessions.add(added);
      _selectedIndex = _sessions.length - 1;
    });
  }
}

class _ClassSession {
  const _ClassSession({
    required this.name,
    required this.time,
    required this.accent,
    required this.icon,
  });

  final String name;
  final String time;
  final Color accent;
  final IconData icon;
}

class _ClassSessionPicker extends StatelessWidget {
  const _ClassSessionPicker({
    required this.sessions,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAddSession,
  });

  final List<_ClassSession> sessions;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAddSession;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Class Sessions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF0B1120),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add class session',
                  onPressed: onAddSession,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < sessions.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == sessions.length - 1 ? 0 : 10,
              ),
              child: _ClassSessionCard(
                session: sessions[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassSessionCard extends StatelessWidget {
  const _ClassSessionCard({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final _ClassSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(selected ? 0.94 : 0.72),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? session.accent.withOpacity(0.48)
                  : Colors.white.withOpacity(0.76),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: session.accent.withOpacity(selected ? 0.14 : 0.05),
                blurRadius: selected ? 28 : 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      session.accent.withOpacity(0.18),
                      session.accent.withOpacity(0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(session.icon, color: session.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B1120),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      session.time,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? session.accent : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2563EB),
            Color(0xFF7C3AED),
            Color(0xFF06B6D4),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.22),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.82),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.58),
                width: 1.5,
              ),
            ),
          ),
          const Icon(
            Icons.psychology_alt_rounded,
            size: 44,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _BackendStatusPill extends StatelessWidget {
  const _BackendStatusPill();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MonitoringProvider>();
    final connected = provider.isBackendConnected;
    final checking = provider.isCheckingHealth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (checking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9CA3AF)),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                boxShadow: [
                  BoxShadow(
                    color: (connected
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444))
                        .withOpacity(0.4),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              checking
                  ? 'Checking...'
                  : connected
                      ? 'Connected'
                      : 'Disconnected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: connected
                    ? const Color(0xFF16A34A)
                    : checking
                        ? const Color(0xFF6B7280)
                        : const Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              provider.backendUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          if (!connected && !checking) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => provider.checkBackendHealth(),
              child: const Icon(
                Icons.refresh_rounded,
                size: 16,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddSessionSheet extends StatefulWidget {
  const _AddSessionSheet();

  @override
  State<_AddSessionSheet> createState() => _AddSessionSheetState();
}

class _AddSessionSheetState extends State<_AddSessionSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _addSession() {
    final name = _nameController.text.trim();
    final time = _timeController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a class name')),
      );
      return;
    }

    Navigator.pop(
      context,
      _ClassSession(
        name: name,
        time: time.isEmpty ? 'Custom session' : time,
        accent: const Color(0xFF0EA5E9),
        icon: Icons.school_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Add Class Session',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF0B1120),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'TTTK4086 Project',
                  prefixIcon: const Icon(Icons.school_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _timeController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addSession(),
                decoration: InputDecoration(
                  labelText: 'Class Time',
                  hintText: '09:00 AM - 10:30 AM',
                  prefixIcon: const Icon(Icons.schedule_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _addSession,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryStartButton extends StatelessWidget {
  const _PrimaryStartButton({
    required this.selected,
    required this.onPressed,
  });

  final _ClassSession selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            selected.accent,
            const Color(0xFF7C3AED),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: selected.accent.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.videocam_rounded),
        label: const Text('Start Session'),
      ),
    );
  }
}
