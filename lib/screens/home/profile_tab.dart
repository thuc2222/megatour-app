import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/language_selector.dart';
import 'package:megatour_app/utils/context_extension.dart';

class ProfileTab extends StatelessWidget {
  final VoidCallback onBookingHistoryTap;

  const ProfileTab({
    Key? key,
    required this.onBookingHistoryTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isLoggedIn = auth.isAuthenticated;
    // 🟢 Defined here to be used throughout the build method
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /// ===============================
          /// HEADER
          /// ===============================
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Colors.blue,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade700,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      /// Avatar
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: isLoggedIn && user?.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  user!.avatarUrl!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(user),
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                      ),

                      const SizedBox(height: 12),

                      /// Name
                      Text(
                        isLoggedIn
                            ? (user?.fullName ?? 'User')
                            : l10n.profile,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      /// Email / Status
                      if (isLoggedIn && user?.email != null)
                        Text(
                          user!.email!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        )
                      else
                        Text(
                          l10n.guestUser, // ✅ Use localized string if available
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          /// ===============================
          /// CONTENT
          /// ===============================
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),

                /// STATS
                if (isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _statCard(Icons.book_online, l10n.bookings),
                        const SizedBox(width: 12),
                        _statCard(Icons.favorite, l10n.wishlist),
                        const SizedBox(width: 12),
                        _statCard(Icons.star, l10n.reviews),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                /// SETTINGS
                _sectionHeader(l10n.settings),
                const LanguageSelector(),

                const SizedBox(height: 16),

                /// ACCOUNT (NOT LOGGED IN)
                if (!isLoggedIn) ...[
                  _sectionHeader('Account'), // Can add l10n.account if defined
                  _menuItem(
                    context,
                    Icons.login,
                    l10n.login,
                    l10n.loginToContinue,
                    () => Navigator.pushNamed(context, '/login'),
                  ),
                  _menuItem(
                    context,
                    Icons.person_add,
                    l10n.register,
                    l10n.startYourJourney,
                    () => Navigator.pushNamed(context, '/register'),
                  ),
                ],

                /// ACCOUNT (LOGGED IN)
                if (isLoggedIn) ...[
                  _sectionHeader('Account'),
                  _menuItem(
                    context,
                    Icons.history,
                    l10n.bookingHistory,
                    l10n.view, // Or 'View your bookings'
                    onBookingHistoryTap,
                  ),
                  _menuItem(
                    context,
                    Icons.favorite_border,
                    l10n.wishlist,
                    l10n.view, // Or 'Saved services'
                    () => Navigator.pushNamed(context, '/wishlist'),
                  ),
                  _menuItem(
                    context,
                    Icons.lock_outline,
                    l10n.password, // "Password" or "Change Password"
                    'Update your password',
                    () => _changePassword(context),
                  ),
                ],

                const SizedBox(height: 16),

                /// APP
                _sectionHeader('App'),
                _menuItem(
                  context,
                  Icons.info_outline,
                  'About',
                  'Application information',
                  () => _about(context),
                ),

                /// LOGOUT
                if (isLoggedIn)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.logout),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ===============================
  /// UI HELPERS
  /// ===============================
  Widget _avatarFallback(dynamic user) {
    return Text(
      user?.firstName?.substring(0, 1).toUpperCase() ?? 'U',
      style: const TextStyle(
        fontSize: 36,
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _statCard(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// ===============================
  /// ACTIONS
  /// ===============================
  void _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _changePassword(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.changePasswordAvailable)), // ✅ Localized
    );
  }

  void _about(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showAboutDialog(
      context: context,
      applicationName: 'Megatour',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.travel_explore),
      children: [
        Text(l10n.yourTravelBookingCompanion), // ✅ Localized
      ],
    );
  }
}