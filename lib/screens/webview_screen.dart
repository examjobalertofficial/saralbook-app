import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/websites.dart';
import '../utils/navigation.dart';
import '../widgets/offline_view.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final String? currentSiteId;
  final bool showSwitcher;

  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
    this.currentSiteId,
    this.showSwitcher = true,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static const List<String> _downloadExtensions = [
    '.pdf', '.zip', '.rar', '.apk', '.doc', '.docx',
    '.xls', '.xlsx', '.ppt', '.pptx', '.csv', '.epub',
  ];

  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  int _progress = 0;
  bool _loading = true;
  bool _hasError = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() => _loading = true);
          },
          onProgress: (p) {
            if (!mounted) return;
            setState(() => _progress = p);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _progress = 100;
            });
          },
          onWebResourceError: _onWebError,
        ),
      );

    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      // Enables the "choose file / photo" dialog for website upload buttons.
      platform.setOnShowFileSelector(_onShowFileSelector);
    }

    _connSub = Connectivity().onConnectivityChanged.listen(_onConnectivity);
    _load();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  bool _isOnlineResult(List<ConnectivityResult> r) =>
      r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);

  Future<bool> _isOnline() async =>
      _isOnlineResult(await Connectivity().checkConnectivity());

  void _onConnectivity(List<ConnectivityResult> r) {
    if (_isOnlineResult(r) && (_offline || _hasError) && mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    final online = await _isOnline();
    if (!mounted) return;
    if (!online) {
      setState(() {
        _offline = true;
        _hasError = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _offline = false;
      _hasError = false;
      _loading = true;
      _progress = 0;
    });
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _onWebError(WebResourceError error) async {
    if (error.isForMainFrame != true) return;
    final online = await _isOnline();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _offline = !online;
      _hasError = online;
    });
  }

  Future<NavigationDecision> _onNavigationRequest(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      const inPage = ['about', 'data', 'blob', 'javascript'];
      if (inPage.contains(uri.scheme)) return NavigationDecision.navigate;
      // tel:, mailto:, whatsapp:, upi: ... -> open the matching phone app
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    final path = uri.path.toLowerCase();
    if (_downloadExtensions.any((e) => path.endsWith(e))) {
      // PDFs and files are handed to the phone (browser / download manager).
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    if (request.isMainFrame && Websites.isExternalHost(uri.host)) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    try {
      final multiple = params.mode == FileSelectorMode.openMultiple;
      final result = await FilePicker.platform.pickFiles(allowMultiple: multiple);
      if (result == null) return [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _handleBack() async {
    if (!_offline && !_hasError && await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _refresh() {
    if (_offline || _hasError) {
      _load();
    } else {
      _controller.reload();
    }
  }

  void _showSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Switch Website',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            for (final site in Websites.all)
              ListTile(
                leading: Icon(site.icon, color: site.color),
                title: Text(site.name),
                trailing: site.id == widget.currentSiteId
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (site.id != widget.currentSiteId) {
                    openWebsite(context, site, replace: true);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refresh,
            ),
            if (widget.showSwitcher)
              IconButton(
                tooltip: 'Switch Website',
                icon: const Icon(Icons.apps_rounded),
                onPressed: _showSwitcher,
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading && !_offline && !_hasError)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress / 100 : null,
                    minHeight: 3,
                  ),
                ),
              if (_offline || _hasError)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _offline
                        ? OfflineView(onRetry: _load)
                        : OfflineView(
                            onRetry: _load,
                            icon: Icons.error_outline_rounded,
                            title: 'Unable to load page',
                            message:
                                'Something went wrong while loading. Please try again.',
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
