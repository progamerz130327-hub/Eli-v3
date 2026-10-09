import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const EliApp());
}

class EliApp extends StatelessWidget {
  const EliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eli 2.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.cyan,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080B10),
      ),
      home: const EliHome(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.fromUser,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        fromUser: json['fromUser'] as bool,
        time: DateTime.parse(json['time'] as String),
      );
}

class EliHome extends StatefulWidget {
  const EliHome({super.key});

  @override
  State<EliHome> createState() => _EliHomeState();
}

class _EliHomeState extends State<EliHome> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _busy = false;
  String _aiEndpoint = '';
  String _syncEndpoint = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _aiEndpoint = prefs.getString('aiEndpoint') ?? '';
    _syncEndpoint = prefs.getString('syncEndpoint') ?? '';
    _deviceId = prefs.getString('deviceId') ??
        'eli-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString('deviceId', _deviceId);

    final saved = prefs.getString('messages');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      _messages.addAll(
        list.map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))),
      );
    }

    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        text: "Hi! I'm Eli 2.0. Connect an AI endpoint in Settings to give me my AI brain.",
        fromUser: false,
        time: DateTime.now(),
      ));
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'messages',
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    _input.clear();
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        fromUser: true,
        time: DateTime.now(),
      ));
      _busy = true;
    });
    await _saveMessages();
    _jump();

    String reply;
    if (_aiEndpoint.isEmpty) {
      reply =
          "I received: \"$text\"\n\nYour AI endpoint isn't connected yet. Open Settings and add your backend URL.";
    } else {
      try {
        final response = await http
            .post(
              Uri.parse(_aiEndpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'message': text,
                'deviceId': _deviceId,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          reply = data['reply']?.toString() ?? 'The AI returned no reply.';
        } else {
          reply = 'AI server error: HTTP ${response.statusCode}';
        }
      } catch (e) {
        reply = 'I could not reach the AI server. Check the endpoint and internet connection.';
      }
    }

    setState(() {
      _messages.add(ChatMessage(
        text: reply,
        fromUser: false,
        time: DateTime.now(),
      ));
      _busy = false;
    });
    await _saveMessages();
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _settings() async {
    final ai = TextEditingController(text: _aiEndpoint);
    final sync = TextEditingController(text: _syncEndpoint);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eli Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ai,
                decoration: const InputDecoration(
                  labelText: 'AI endpoint',
                  hintText: 'https://your-server/chat',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sync,
                decoration: const InputDecoration(
                  labelText: 'Sync endpoint',
                  hintText: 'https://your-server',
                ),
              ),
              const SizedBox(height: 12),
              Text('Device ID: $_deviceId',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('aiEndpoint', ai.text.trim());
              await prefs.setString('syncEndpoint', sync.text.trim());
              setState(() {
                _aiEndpoint = ai.text.trim();
                _syncEndpoint = sync.text.trim();
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome),
            SizedBox(width: 10),
            Text('Eli 2.0'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _settings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 700),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: m.fromUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : const Color(0xFF151A22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Eli is thinking...'),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Talk to Eli...',
                        filled: true,
                        fillColor: const Color(0xFF151A22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _busy ? null : _send,
                    child: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
