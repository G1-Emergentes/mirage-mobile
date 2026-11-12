import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../avatar/presentation/avatar_screen.dart';
import '../../../shared/config/app_environment.dart';
import '../../../shared/network/api_client.dart';
import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_components.dart';
import '../../../shared/widgets/mirage_feature_components.dart';
import '../../application/iam_controller.dart';
import '../../infrastructure/dio_profile_repository.dart';
import 'profile_editor_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.controller,
    this.bottomNavigationBar,
    this.onContinueHome,
    this.onOpenCloset,
    this.profileRepository,
  });

  final IamController controller;
  final Widget? bottomNavigationBar;
  final VoidCallback? onContinueHome, onOpenCloset;
  final DioProfileRepository? profileRepository;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _defaultPhoto = 'assets/design/editorial.png';
  ApiClient? _client;
  late final _repository =
      widget.profileRepository ??
      DioProfileRepository(
        _client = ApiClient(AppEnvironment.local().apiBaseUrl),
        widget.controller.avatarAccessToken,
      );
  Map<String, dynamic>? _profile;
  String? _loadError;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final account = widget.controller.account;
    if (_loading || account == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await _repository.load(account.id);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(ProfileSection section) async {
    final profile = _profile;
    final userId = widget.controller.account?.id;
    if (profile == null || userId == null || _loading) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProfileEditorScreen(
          section: section,
          profile: profile,
          save: (data) => _repository.save(userId, section, data),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(
      () => _profile = section == ProfileSection.identity
          ? result
          : {...profile, section.name: result},
    );
  }

  Future<void> _openAvatar() async {
    final completed = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) =>
            AvatarScreen(accessToken: widget.controller.avatarAccessToken),
      ),
    );
    if (!mounted) return;
    if (completed == true) widget.onContinueHome?.call();
    if (completed == 'closet') widget.onOpenCloset?.call();
  }

  Widget _photo() {
    final fallback = Image.asset(_defaultPhoto, fit: BoxFit.cover);
    final url = _profile?['profileImageUrl'];
    return url is String && url.isNotEmpty
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : fallback;
  }

  void _pending(String title) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        title == 'Terms & Conditions' || title == 'Privacy Policy'
            ? 'The official document is not available in the app yet.'
            : 'This feature is not available yet.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  void _photos() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => MirageFeaturePage(
        title: 'My Photos',
        onBack: () => Navigator.pop(context),
        children: [
          if (_profile?['profileImageUrl'] is String) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(height: 240, child: _photo()),
            ),
            const SizedBox(height: 12),
          ] else
            const MirageNotice('You are using the default profile image.'),
          MirageButton(
            label: 'Edit Profile Photo',
            onPressed: _profile == null
                ? null
                : () {
                    Navigator.pop(context);
                    _edit(ProfileSection.identity);
                  },
          ),
          OutlinedButton(
            onPressed: kReleaseMode
                ? null
                : () {
                    Navigator.pop(context);
                    _openAvatar();
                  },
            child: const Text('Open Body Profile'),
          ),
        ],
      ),
    ),
  );

  void _settings() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Account Settings'),
      content: Text(widget.controller.account?.email ?? ''),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: widget.controller.busy
              ? null
              : () {
                  Navigator.pop(context);
                  widget.controller.signOut();
                },
          child: const Text('Log Out'),
        ),
      ],
    ),
  );

  Widget _group(String title, List<Widget> options) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: MirageColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(children: options),
        ),
      ],
    ),
  );

  Widget _option(String label, IconData icon, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MirageColors.muted),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          const Icon(Icons.chevron_right, size: 16, color: MirageColors.muted),
        ],
      ),
    ),
  );

  Widget _future(String label, IconData icon) =>
      _option(label, icon, () => _pending(label));

  @override
  Widget build(BuildContext context) {
    final name =
        _profile?['displayName'] as String? ??
        widget.controller.account?.displayName;
    final canEdit = _profile != null && !_loading;
    return MirageScreen(
      topPadding: 6,
      bottomNavigationBar: widget.bottomNavigationBar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: widget.onContinueHome,
                icon: const MirageDesignIcon('back'),
              ),
              const MirageWordmark(size: 17),
              IconButton(
                tooltip: 'Account Settings',
                onPressed: _settings,
                icon: const Icon(Icons.settings_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MirageColors.lavender,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox.square(dimension: 56, child: _photo()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name?.isNotEmpty == true ? name! : 'Profile',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 25),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Your style, reimagined. ✦',
                        style: TextStyle(
                          fontSize: 11,
                          color: MirageColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Profile',
                  onPressed: canEdit
                      ? () => _edit(ProfileSection.identity)
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null) ...[
            MirageNotice(_loadError!, error: true),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
          if (widget.controller.error case final error?)
            MirageNotice(error, error: true),
          _group('MY ACCOUNT', [
            _option(
              'Body Profile',
              Icons.person_outline,
              kReleaseMode ? null : _openAvatar,
            ),
            _option('My Photos', Icons.photo_library_outlined, _photos),
            _option(
              'Measurements',
              Icons.straighten_outlined,
              canEdit ? () => _edit(ProfileSection.measurements) : null,
            ),
            _option(
              'Preferences',
              Icons.tune,
              canEdit ? () => _edit(ProfileSection.preferences) : null,
            ),
          ]),
          _group('MY STYLE', [
            _future('Saved Outfits', Icons.checkroom_outlined),
            _future('Favorites', Icons.favorite_outline),
            _future('AI Previews', Icons.auto_awesome_outlined),
          ]),
          _group('SETTINGS', [
            _future('Language', Icons.language_outlined),
            _future('Privacy', Icons.lock_outline),
            _future('Notifications', Icons.notifications_outlined),
          ]),
          _group('LEGAL', [
            _future('Terms & Conditions', Icons.description_outlined),
            _future('Privacy Policy', Icons.verified_user_outlined),
          ]),
          const Text(
            'Mirage by ReWear · Made for your real wardrobe',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: MirageColors.muted),
          ),
        ],
      ),
    );
  }
}
