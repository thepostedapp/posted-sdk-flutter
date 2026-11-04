import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posted_sdk/posted_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env file: the placeholders below are used and the report fails with 401.
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Reporting install…';

  @override
  void initState() {
    super.initState();
    _reportInstall();
  }

  Future<void> _reportInstall() async {
    // Report the install on every launch. The SDK sends it once per install
    // and retries on later launches until the backend accepts it. Awaiting is
    // optional; this example awaits only to show when the call has finished.
    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};
    await Posted.reportInstall(
      PostedConfig(
        apiKey: env['POSTED_API_KEY'] ?? '<YOUR_API_KEY>',
        appID: env['POSTED_APP_ID'] ?? '<YOUR_APP_ID>',
      ),
    );
    if (!mounted) return;
    setState(() => _status = 'Install report finished');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('posted_sdk Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: $_status'),
              const SizedBox(height: 16),
              const Text(
                'The install is reported once. Uninstall and reinstall the app '
                'to report again. The result is in the native logs: Logcat tag '
                'PostedApiClient on Android, Console subsystem '
                'com.postedapp.posted on iOS.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
