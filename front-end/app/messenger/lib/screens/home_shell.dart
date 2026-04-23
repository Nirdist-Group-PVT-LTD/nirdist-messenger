import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../state/session_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.profile});

  final ProfileSummary profile;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeTab(
        profile: widget.profile,
        onOpenChats: () => setState(() => _selectedIndex = 1),
      ),
      const ChatsTab(),
      ProfileTab(profile: widget.profile),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.profile, required this.onOpenChats});

  final ProfileSummary profile;
  final VoidCallback onOpenChats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF071018),
            Color(0xFF08131C),
            Color(0xFF061016),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            _TopBar(profile: profile),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.96, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: _HeroCard(
                profile: profile,
                onOpenChats: onOpenChats,
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Core modules',
              subtitle: 'What the Android MVP is already set up to support',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'Messages',
                        subtitle: 'Private rooms stay locked behind accepted friendships.',
                        accent: colorScheme.primary,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(
                        icon: Icons.contacts_outlined,
                        title: 'Contacts',
                        subtitle: 'Phonebook sync surfaces matched users and suggestions.',
                        accent: colorScheme.secondary,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Stories',
                        subtitle: '24-hour media stories are part of the next wave.',
                        accent: colorScheme.tertiary,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _FeatureCard(
                        icon: Icons.videocam_outlined,
                        title: 'Calls',
                        subtitle: 'WebRTC signaling and TURN support are queued up next.',
                        accent: const Color(0xFFFF8A65),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'Ready status',
              subtitle: 'The shell now persists your JWT and profile in secure storage.',
            ),
            const SizedBox(height: 12),
            _TimelineCard(
              icon: Icons.verified_outlined,
              title: 'Authenticated session',
              description: 'The app restores the backend JWT after restart.',
            ),
            const SizedBox(height: 10),
            _TimelineCard(
              icon: Icons.security_outlined,
              title: 'Accepted-friend gating',
              description: 'The backend only allows private rooms and calls after acceptance.',
            ),
            const SizedBox(height: 10),
            _TimelineCard(
              icon: Icons.sync_outlined,
              title: 'Mobile-first roadmap',
              description: 'Phase 1 is now moving from backend-only work into the Android client.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF071018),
            Color(0xFF09141D),
            Color(0xFF061016),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            _TopBar(
              profile: context.select((SessionController controller) => controller.session!.profile),
              title: 'Chats',
              subtitle: 'Accepted friendships unlock private rooms and call access.',
            ),
            const SizedBox(height: 18),
            const _EmptyStateCard(
              icon: Icons.forum_outlined,
              title: 'No live chat list yet',
              subtitle: 'The backend is ready, and the next client slice can hydrate rooms and recent messages.',
            ),
            const SizedBox(height: 12),
            const _TimelineCard(
              icon: Icons.group_add_outlined,
              title: 'Friendship gate',
              description: 'Private rooms remain invisible until both people accept.',
            ),
            const SizedBox(height: 12),
            const _TimelineCard(
              icon: Icons.mark_chat_unread_outlined,
              title: 'Message cache',
              description: 'Recent messages are cached on device as soon as the room opens.',
            ),
            const SizedBox(height: 12),
            const _TimelineCard(
              icon: Icons.layers_outlined,
              title: 'STOMP topics',
              description: 'The backend already broadcasts to room topics for real-time sync.',
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF071018),
            Color(0xFF08131C),
            Color(0xFF061016),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            _TopBar(
              profile: profile,
              title: 'Profile',
              subtitle: 'Your identity is backed by the backend JWT and secure storage.',
            ),
            const SizedBox(height: 18),
            _ProfileHero(profile: profile),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Account details',
              subtitle: 'Loaded from the auth exchange response.',
            ),
            const SizedBox(height: 12),
            _DetailCard(
              rows: <_DetailRow>[
                _DetailRow(label: 'Username', value: profile.username ?? '—'),
                _DetailRow(label: 'Display name', value: profile.displayName ?? '—'),
                _DetailRow(label: 'Email', value: profile.email ?? '—'),
                _DetailRow(label: 'Phone', value: profile.phoneNumber ?? '—'),
                _DetailRow(label: 'Firebase UID', value: profile.firebaseUid ?? '—'),
                _DetailRow(label: 'Phone verified', value: _formatDate(profile.phoneVerifiedAt)),
                _DetailRow(label: 'Created', value: _formatDate(profile.createdAt)),
                _DetailRow(label: 'Updated', value: _formatDate(profile.updatedAt)),
              ],
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Session security',
              subtitle: 'The JWT stays encrypted on device and can be removed instantly.',
            ),
            const SizedBox(height: 12),
            _DetailCard(
              rows: <_DetailRow>[
                _DetailRow(label: 'Backend URL', value: controller.apiBaseUrl),
                _DetailRow(label: 'Token preview', value: _maskedToken(controller.session?.token ?? '')),
                _DetailRow(label: 'Secure storage', value: 'Enabled'),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: controller.isSubmitting
                  ? null
                  : () async {
                      final shouldSignOut = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('Sign out?'),
                            content: const Text('This removes the stored JWT and returns you to the login screen.'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                child: const Text('Sign out'),
                              ),
                            ],
                          );
                        },
                      );

                      if (shouldSignOut == true && context.mounted) {
                        await context.read<SessionController>().signOut();
                      }
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    this.title,
    this.subtitle,
  });

  final ProfileSummary profile;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = title ?? 'Welcome back';
    final effectiveSubtitle = subtitle ?? 'Signed in as ${profile.displayLabel}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color(0xFF0ED1C6).withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              profile.initials,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(effectiveTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(effectiveSubtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.profile, required this.onOpenChats});

  final ProfileSummary profile;
  final VoidCallback onOpenChats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF10262F),
            Color(0xFF0D1720),
            Color(0xFF09131B),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF0ED1C6).withValues(alpha: 0.26),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onOpenChats,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Open chats'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              profile.displayLabel,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '@${profile.username ?? 'unknown'} · vId ${profile.vId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StatusChip(label: 'JWT secured'),
                _StatusChip(label: profile.phoneNumber ?? 'No phone linked'),
                _StatusChip(label: profile.phoneVerifiedAt == null ? 'Phone unverified' : 'Phone verified'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 164,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.14),
            const Color(0xFF0D1720),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0D1720),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
              ),
            ),
            child: Icon(icon, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF10232B),
            Color(0xFF0D1720),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF0ED1C6), Color(0xFFFFB84D)],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF0ED1C6).withValues(alpha: 0.2),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                profile.initials,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(profile.displayLabel, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('@${profile.username ?? 'unknown'}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StatusChip(label: 'vId ${profile.vId}'),
                    _StatusChip(label: profile.phoneVerifiedAt == null ? 'Not verified' : 'Verified'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});

  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1720),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: List<Widget>.generate(rows.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(height: 20, color: Colors.white.withValues(alpha: 0.08));
          }

          return rows[index ~/ 2];
        }),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

String _formatDate(DateTime? dateTime) {
  if (dateTime == null) {
    return '—';
  }

  final local = dateTime.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
}

String _maskedToken(String token) {
  if (token.isEmpty) {
    return '—';
  }

  if (token.length <= 10) {
    return '••••••••';
  }

  return '••••••••${token.substring(token.length - 10)}';
}