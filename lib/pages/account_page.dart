import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/token_service.dart';
import '../ui/nv.dart';
import 'edit_profile_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = _profile == null;
      _error = null;
    });
    try {
      final token = await TokenService.getCurrentToken();
      final result = await ApiService.getProfile(token);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _profile = Map<String, dynamic>.from(result['data']));
      } else {
        setState(() => _error = (result['message'] ?? 'Couldn’t load your profile').toString());
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t reach Notevia. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(profileData: _profile!)),
    );
    if (saved == true) _fetch();
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  String _date(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    if (d == null) return '';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), shape: Border(bottom: BorderSide(color: c.lineMuted))),
      body: _body(c),
    );
  }

  Widget _body(NvColors c) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(NvSpace.gutter),
        child: Row(
          children: [
            NvSkeleton(width: 64, height: 64, radius: 32),
            SizedBox(width: NvSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [NvSkeleton(width: 160, height: 18), SizedBox(height: 8), NvSkeleton(width: 120, height: 12)],
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null || _profile == null) {
      return Center(
        child: NvEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn’t load your profile',
          message: _error,
          actionLabel: 'Try again',
          secondary: true,
          onAction: _fetch,
        ),
      );
    }

    final p = _profile!;
    final name = (p['full_name'] ?? '').toString().trim();
    final bio = (p['bio'] ?? '').toString().trim();
    final dob = _date(p['date_of_birth']);
    final since = _date(p['created_at']);

    return RefreshIndicator(
      onRefresh: _fetch,
      color: c.accent,
      backgroundColor: c.surface2,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(NvSpace.gutter, NvSpace.lg, NvSpace.gutter, NvSpace.xxl),
        children: [
          Row(
            children: [
              NvAvatar(url: (p['profile_picture'] ?? '').toString(), name: name, size: 64),
              const SizedBox(width: NvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Add your name' : name, style: NvText.title.copyWith(color: c.fg)),
                    if (since.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Member since $since', style: NvText.meta.copyWith(color: c.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NvSpace.lg),
          NvButton.secondary(label: 'Edit profile', icon: Icons.edit_outlined, expand: true, onPressed: _edit),
          const NvSectionHeader('About'),
          NvBox(
            padding: const EdgeInsets.all(NvSpace.md),
            children: [
              Text(
                bio.isEmpty ? 'No bio yet.' : bio,
                style: NvText.body.copyWith(color: bio.isEmpty ? c.muted : c.text),
              ),
            ],
          ),
          if (dob.isNotEmpty) ...[
            const NvSectionHeader('Details'),
            NvBox(children: [NvRow(title: 'Date of birth', trailing: Text(dob, style: NvText.small.copyWith(color: c.muted)))]),
          ],
        ],
      ),
    );
  }
}

/// Round profile photo, or initials when there is none.
class NvAvatar extends StatelessWidget {
  const NvAvatar({super.key, required this.url, required this.name, this.size = 40, this.file});
  final String url;
  final String name;
  final double size;
  final ImageProvider? file;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final fallback = Container(
      color: c.surface2,
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: NvText.heading.copyWith(color: c.muted, fontSize: size * 0.36),
      ),
    );
    final ImageProvider? image = file ?? (url.isNotEmpty ? NetworkImage(url) : null);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.line)),
      child: ClipOval(
        child: image == null
            ? fallback
            : Image(image: image, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
      ),
    );
  }
}
