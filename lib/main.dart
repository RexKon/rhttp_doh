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
                for (final answer in (data['Answer'] as List)) {
                  final type = answer['type'] as int?;
                  final recordData = answer['data'] as String?;
                  if (type == 1 && recordData != null) {
                    return [recordData];
                  }
                }
                return [host];
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

    try {
      final response = await client.get(
        url,
        headers: HttpHeaders.rawMap({
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Cache-Control': 'max-age=0',
        }),
      );
      await webViewController.loadData(data: response.body, baseUrl: WebUri(url), mimeType: 'text/html');
    } catch (e) {
      print('Error loading page: $e');
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
