import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape and fullscreen
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const RDKWebRTCApp());
}

class RDKWebRTCApp extends StatelessWidget {
  const RDKWebRTCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDK WebRTC Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
      ),
      home: const ViewerPage(),
    );
  }
}

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final WebViewController _controller;
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.3.105');
  String _status = 'Disconnected';
  Color _statusColor = Colors.red;
  bool _connected = false;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // Receive status updates from JavaScript via console.log("STATUS:...")
      ..addJavaScriptChannel(
        'Flutter',
        onMessageReceived: (JavaScriptMessage msg) {
          _updateStatus(msg.message);
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          // Inject a bridge so JS can talk to Flutter
          _controller.runJavaScript('''
            // Override console.log to forward STATUS: messages to Flutter
            (function() {
              var origLog = console.log;
              console.log = function() {
                var msg = Array.from(arguments).join(' ');
                if (msg.startsWith('STATUS:')) {
                  Flutter.postMessage(msg.substring(7));
                }
                origLog.apply(console, arguments);
              };
            })();
          ''');
        },
      ))
      ..loadFlutterAsset('assets/webrtc_viewer.html');
  }

  void _updateStatus(String status) {
    setState(() {
      _status = status;
      if (status.contains('Streaming') || status.contains('CONNECTED')) {
        _statusColor = const Color(0xFF27ae60);
        _connected = true;
        // Auto-hide controls after streaming starts
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _connected) {
            setState(() => _controlsVisible = false);
          }
        });
      } else if (status.contains('Disconnect') || status.contains('error')) {
        _statusColor = const Color(0xFFc0392b);
        _connected = false;
        _controlsVisible = true;
      } else {
        _statusColor = const Color(0xFFf39c12);
      }
    });
  }

  void _connect() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _status = 'Connecting...';
      _statusColor = const Color(0xFFf39c12);
      _connected = false;
    });
    _controller.runJavaScript("connectTo('$ip')");
  }

  void _disconnect() {
    _controller.runJavaScript('disconnect()');
    setState(() {
      _status = 'Disconnected';
      _statusColor = const Color(0xFFc0392b);
      _connected = false;
      _controlsVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        // Tap to toggle controls visibility
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          children: [
            // WebView fills entire screen
            WebViewWidget(controller: _controller),

            // Top control bar (animated show/hide)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: _controlsVisible ? 0 : -80,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 8, right: 8, bottom: 4,
                ),
                color: Colors.black54,
                child: Row(
                  children: [
                    // IP input
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _ipController,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: '192.168.x.x',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: const Color(0xFF16213e),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(':8080',
                        style: TextStyle(color: Colors.grey, fontSize: 14,
                          fontFamily: 'monospace'),
                      ),
                    ),
                    // Connect button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _connected ? null : _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0f3460),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Connect', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Disconnect button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: _connected ? _disconnect : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0f3460),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom status bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _statusColor, fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
