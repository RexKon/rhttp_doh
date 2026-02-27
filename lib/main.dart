import 'package:flutter/material.dart';
import 'package:rhttp/rhttp.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:convert';

Future<void> main() async {
  await Rhttp.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'DoH Browser', theme: ThemeData(useMaterial3: true), home: const BrowserPage());
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late InAppWebViewController webViewController;
  late RhttpClient client;
  final urlController = TextEditingController();
  String? resolvedIp;
  String? resolvedDomain;

  @override
  void initState() {
    super.initState();
    _initClient();
  }

  Future<void> _initClient() async {
    client = await RhttpClient.create(
      settings: ClientSettings(
        dnsSettings: DnsSettings.dynamic(
          resolver: (String host) async {
            final response = await Rhttp.get(
              'https://1.1.1.1/dns-query',
              query: {'name': host, 'type': 'A'},
              headers: const HttpHeaders.rawMap({'Accept': 'application/dns-json'}),
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['Answer'] != null && (data['Answer'] as List).isNotEmpty) {
                final ip = data['Answer'][0]['data'] as String;
                if (mounted) {
                  setState(() {
                    resolvedDomain = host;
                    resolvedIp = ip;
                  });
                }
                return [ip];
              }
            }
            return [host];
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }

  void navigate() async {
    var url = urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';

    final uri = Uri.parse(url);
    await client.get(uri.toString());

    if (resolvedIp != null) {
      final ipUri = uri.replace(host: resolvedIp!);
      final ipUrl = ipUri.toString();
      print('Loading IP URL: $ipUrl');
      await webViewController.loadUrl(urlRequest: URLRequest(url: WebUri(ipUrl)));
    } else {
      await webViewController.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('DoH Browser (1.1.1.1)')),
      body: Column(
        children: [
          Column(
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      decoration: InputDecoration(
                        hintText: 'URL',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      onSubmitted: (_) => navigate(),
                    ),
                  ),
                  ElevatedButton(onPressed: navigate, child: Text('Go')),
                ],
              ),
              if (resolvedDomain != null)
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue[50]),
                  child: Text('DoH: $resolvedDomain => $resolvedIp'),
                ),
            ],
          ),
          Expanded(
            child: InAppWebView(
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }
}
