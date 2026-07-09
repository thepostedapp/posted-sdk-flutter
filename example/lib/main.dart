import 'package:posted_sdk/posted_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Local fallback for CI/tests without .env file.
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final _postedService = PostedService();

  PostedIntent? _initialIntent;
  PostedIntent? _runtimeIntent;
  PostedIntent? _manualIntent;
  PostedResult? _processedResult;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _postedService.addListener(_onPostedChanged);
    _init();
  }

  Future<void> _init() async {
    try {
      await _postedService.start(
        PostedConfig(
          apiKey: dotenv.env['POSTED_API_KEY'] ?? 'YOUR_API_KEY',
          appID: dotenv.env['POSTED_APP_ID'] ?? 'YOUR_APP_ID',
          shouldUseClipboard: true,
          linkProcessingMode: PostedLinkProcessingMode.all,
        ),
      );

      if (mounted &&
          _postedService.isInitialLinkProcessed &&
          _status == 'Initializing...') {
        setState(() => _status = 'Ready');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Error: ${e.message}');
    }
  }

  void _onPostedChanged() {
    if (!mounted) return;

    final intent = _postedService.pendingIntent;
    if (intent != null) {
      setState(() {
        switch (intent.source) {
          case PostedIntentSource.initial:
            _initialIntent = intent;
            break;
          case PostedIntentSource.runtime:
            _runtimeIntent = intent;
            break;
          case PostedIntentSource.manual:
            _manualIntent = intent;
            break;
        }
        _status = 'Handled ${intent.source.name} intent';
      });
      _postedService.consumePendingIntent();
      return;
    }

    if (_postedService.isInitialLinkProcessed && _status == 'Initializing...') {
      setState(() => _status = 'Ready');
    }
  }

  @override
  void dispose() {
    _postedService.removeListener(_onPostedChanged);
    _postedService.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _processTestLink() async {
    try {
      final result = await _postedService.processLink(
        // Use a test URL that matches your posted-sdk dashboard setup for testing.
        'https://posted.link/abc123?campaign=test',
      );
      if (!mounted) return;
      setState(() => _processedResult = result);
      _showSnackBar('processLink completed (processed: ${result.processed})');
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'processLink error: ${e.message}');
      _showSnackBar('processLink error: ${e.message}');
    }
  }

  Future<void> _logEvent() async {
    await _postedService.logEvent(
      PostedEventName.purchase,
      data: {'value': 9.99, 'currency': 'USD'},
    );
    if (!mounted) return;
    setState(() => _status = 'logEvent sent');
    _showSnackBar('logEvent sent (purchase)');
  }

  Future<void> _logRetention() async {
    await _postedService.logRetention('home_screen_viewed');
    if (!mounted) return;
    setState(() => _status = 'logRetention sent');
    _showSnackBar('logRetention sent (home_screen_viewed)');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      home: Scaffold(
        appBar: AppBar(title: const Text('posted-sdk Flutter Example')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 8),
              Text(
                'Initial processed: ${_postedService.isInitialLinkProcessed}',
              ),
              const SizedBox(height: 16),
              _IntentCard('Initial Intent', _initialIntent),
              const SizedBox(height: 8),
              _IntentCard('Runtime Intent', _runtimeIntent),
              const SizedBox(height: 8),
              _IntentCard('Manual Intent', _manualIntent),
              const SizedBox(height: 8),
              _ResultCard('processLink() Result', _processedResult),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _processTestLink,
                    child: const Text('Process Test Link'),
                  ),
                  ElevatedButton(
                    onPressed: _logEvent,
                    child: const Text('Log Event'),
                  ),
                  ElevatedButton(
                    onPressed: _logRetention,
                    child: const Text('Log Retention'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard(this.title, this.intent);

  final String title;
  final PostedIntent? intent;

  @override
  Widget build(BuildContext context) {
    final value = intent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (value == null)
              const Text('None')
            else ...[
              Text('source: ${value.source.name}'),
              Text('type: ${value.link.type.name}'),
              Text('route: ${value.link.route}'),
              Text('pathname: ${value.link.pathname}'),
              Text('params: ${value.link.params}'),
              Text('url: ${value.link.url}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final PostedResult? result;

  const _ResultCard(this.title, this.result);

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (r == null)
              const Text('None')
            else if (r.link == null)
              Text('processed: ${r.processed}, link: null')
            else ...[
              Text('type: ${r.link!.type.name}'),
              Text('route: ${r.link!.route}'),
              Text('pathname: ${r.link!.pathname}'),
              Text('params: ${r.link!.params}'),
              Text('url: ${r.link!.url}'),
            ],
          ],
        ),
      ),
    );
  }
}
