import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_components.dart';
import '../../application/iam_controller.dart';
import '../../../avatar/presentation/avatar_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    this.bottomNavigationBar,
    this.onContinueHome,
    this.onOpenCloset,
  });
  final IamController controller;
  final Widget? bottomNavigationBar;
  final VoidCallback? onContinueHome, onOpenCloset;
  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    return MirageScreen(
      bottomNavigationBar: bottomNavigationBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MirageHeader(),
          const SizedBox(height: 44),
          Text(
            'Your profile.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16),
          Text(
            account.displayName.isEmpty
                ? 'Welcome to Mirage.'
                : 'Welcome, ${account.displayName}.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: MirageColors.lavender,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR MIRAGE ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(account.email, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                  account.emailConfirmed
                      ? 'Email confirmed'
                      : 'Email confirmation pending',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MirageButton(
            label: 'My digital avatar',
            onPressed: kReleaseMode
                ? null
                : () async {
                    // true: avatar saved. 'closet': the user kept a body photo instead.
                    final completed = await Navigator.of(context).push<Object?>(
                      MaterialPageRoute<Object?>(
                        builder: (_) => AvatarScreen(
                          accessToken: controller.avatarAccessToken,
                        ),
                      ),
                    );
                    if (!context.mounted) return;
                    if (completed == true) onContinueHome?.call();
                    if (completed == 'closet') onOpenCloset?.call();
                  },
          ),
          const SizedBox(height: 14),
          if (controller.error != null) ...[
            MirageNotice(controller.error!, error: true),
            const SizedBox(height: 20),
          ],
          MirageButton(
            label: 'Check my account',
            busy: controller.busy,
            arrow: false,
            onPressed: controller.queryCurrentAccount,
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: controller.busy ? null : controller.signOut,
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
