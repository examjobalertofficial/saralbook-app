import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_services.dart';
import '../../core/config/control.dart';
import '../../core/config/site_check.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../tools/tool_catalog.dart';

/// Owner / admin panel. It only appears for accounts listed in the cloud
/// (`admins/{uid}`), and the cloud rules check that again on every save.
/// Nothing secret is stored in the app.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  AppControl _c = AppControl.empty;
  bool _inited = false;
  bool _saving = false;
  bool _checking = false;
  List<SiteStatus>? _sites;

  final _maintMsg = TextEditingController();
  final _minBuild = TextEditingController();
  final _latestBuild = TextEditingController();
  final _updMsg = TextEditingController();
  final _updUrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;
    _c = AppScope.of(context).config.control;
    _maintMsg.text = _c.maintenanceMessage;
    _minBuild.text = _c.update.minBuild == 0 ? '' : '${_c.update.minBuild}';
    _latestBuild.text = _c.update.latestBuild == 0 ? '' : '${_c.update.latestBuild}';
    _updMsg.text = _c.update.message;
    _updUrl.text = _c.update.url;
  }

  @override
  void dispose() {
    _maintMsg.dispose();
    _minBuild.dispose();
    _latestBuild.dispose();
    _updMsg.dispose();
    _updUrl.dispose();
    super.dispose();
  }

  int _num(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  /// What the form currently says.
  AppControl _collect() => _c.copyWith(
        maintenanceMessage: _maintMsg.text.trim(),
        update: UpdatePolicy(
          minBuild: _num(_minBuild),
          latestBuild: _num(_latestBuild),
          message: _updMsg.text.trim(),
          url: _updUrl.text.trim(),
        ),
      );

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, save')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final next = _collect();
    final services = AppScope.of(context);
    if (next.update.url.isNotEmpty && !UpdatePolicy.isSafeTarget(next.update.url)) {
      _say('Update address must be https on your own sites or your Google Play page.');
      return;
    }
    if (next.update.minBuild > 0 && next.update.latestBuild > 0 && next.update.minBuild > next.update.latestBuild) {
      _say('"Must update below build" cannot be higher than "Latest build".');
      return;
    }
    final warnings = <String>[
      if (next.maintenanceEnabled && next.maintenanceBlocking)
        'Everyone except admins will see a full-screen maintenance message.',
      if (next.update.minBuild > services.config.currentBuild && services.config.currentBuild > 0)
        'Every phone running build ${services.config.currentBuild} (the newest you have) will be blocked.',
      if (next.update.minBuild > 0 &&
          next.update.minBuild <= services.config.currentBuild &&
          next.update.minBuild > 1)
        'Phones older than build ${next.update.minBuild} will be asked to update.',
    ];
    if (warnings.isNotEmpty && !await _confirm(warnings.join('\n\n'))) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await services.admin.save(next);
    if (!mounted) return;
    setState(() => _saving = false);
    _say(ok ? 'Saved. Everyone gets it within a few minutes.' : 'Could not save. Check your internet and that you are still an admin.');
  }

  Future<void> _reset() async {
    if (!await _confirm('This removes every switch you set here. The app goes back to what the website says.')) return;
    if (!mounted) return;
    setState(() => _saving = true);
    final ok = await AppScope.of(context).admin.reset();
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _c = AppControl.empty;
        _maintMsg.clear();
        _minBuild.clear();
        _latestBuild.clear();
        _updMsg.clear();
        _updUrl.clear();
      }
    });
    _say(ok ? 'All switches cleared.' : 'Could not reset. Check your internet.');
  }

  Future<void> _checkSites() async {
    final sites = AppScope.of(context).config.sites;
    setState(() => _checking = true);
    final result = await checkSites(sites);
    if (!mounted) return;
    setState(() {
      _sites = result;
      _checking = false;
    });
  }

  Widget _head(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([services.admin, services.config]),
      builder: (context, _) {
        if (!services.admin.isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin panel')),
            body: const Center(child: Text('This account is not an admin.')),
          );
        }
        final saved = services.config.control;
        final tools = [...toolCatalog]..sort((a, b) => a.title.of('en').compareTo(b.title.of('en')));
        return Scaffold(
          appBar: AppBar(title: const Text('Admin panel', style: TextStyle(fontWeight: FontWeight.w700))),
          body: PageBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Signed in as ${services.auth.user?.email ?? ''}'),
                        const SizedBox(height: 4),
                        Text(
                          'This app: build ${services.config.currentBuild == 0 ? '?' : services.config.currentBuild}'
                          '${saved.updatedAt == 0 ? '' : '  -  last saved ${DateTime.fromMillisecondsSinceEpoch(saved.updatedAt)}'}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'These switches are saved in the cloud and work together with the WordPress settings. '
                          'They can turn things off or ask for an update; they never re-open something the website closed. '
                          'You are never locked out of the app yourself.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),

                _head('Maintenance'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show maintenance notice'),
                  subtitle: const Text('A banner on Home'),
                  value: _c.maintenanceEnabled,
                  onChanged: (v) => setState(() => _c = _c.copyWith(maintenanceEnabled: v)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Block the whole app'),
                  subtitle: const Text('Full-screen message for everyone except admins. Emergencies only.'),
                  value: _c.maintenanceBlocking,
                  onChanged: _c.maintenanceEnabled ? (v) => setState(() => _c = _c.copyWith(maintenanceBlocking: v)) : null,
                ),
                TextField(
                  controller: _maintMsg,
                  maxLength: 400,
                  decoration: const InputDecoration(labelText: 'Message (optional)', border: OutlineInputBorder()),
                ),

                _head('Features'),
                for (final id in FeatureFlags.all)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(FeatureFlags.labels[id] ?? id),
                    subtitle: Text(_c.flagOn(id) ? 'On' : 'Turned off for everyone'),
                    value: _c.flagOn(id),
                    onChanged: (v) => setState(() => _c = _c.copyWith(flags: {..._c.flags, id: v})),
                  ),

                _head('Tools'),
                Card(
                  child: ExpansionTile(
                    title: Text(_c.disabledTools.isEmpty ? 'All tools on' : '${_c.disabledTools.length} tool(s) turned off'),
                    children: [
                      for (final e in tools)
                        SwitchListTile(
                          title: Text(tr(context, e.title)),
                          subtitle: Text(e.id),
                          value: !_c.disabledTools.contains(e.id),
                          onChanged: (v) => setState(() {
                            final next = {..._c.disabledTools};
                            if (v) {
                              next.remove(e.id);
                            } else {
                              next.add(e.id);
                            }
                            _c = _c.copyWith(disabledTools: next);
                          }),
                        ),
                    ],
                  ),
                ),

                _head('App updates'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minBuild,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Must update below build',
                          helperText: 'Blocks older apps',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _latestBuild,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Latest build',
                          helperText: 'Shows "update available"',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _updMsg,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: 'Update message (optional)', border: OutlineInputBorder()),
                ),
                TextField(
                  controller: _updUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Where to update (optional)',
                    helperText: 'https link on your sites or your Google Play page. Empty = Google Play.',
                    border: OutlineInputBorder(),
                  ),
                ),

                _head('Websites'),
                FilledButton.tonalIcon(
                  onPressed: _checking ? null : _checkSites,
                  icon: _checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_rounded),
                  label: const Text('Check all websites now'),
                ),
                if (_sites != null)
                  for (final s in _sites!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: s.ok ? Colors.green : scheme.error,
                      ),
                      title: Text(s.name),
                      subtitle: Text(s.code == null ? 'No answer' : 'HTTP ${s.code} - ${s.ms} ms'),
                    ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save for everyone'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _reset,
                  child: const Text('Clear all switches'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
