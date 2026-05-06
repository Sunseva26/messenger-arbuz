import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Замени на свой URL сервера
const String SERVER_URL = 'https://твой_ник.pythonanywhere.com';

void main() {
  runApp(const ArbuzApp());
}

class ArbuzApp extends StatelessWidget {
  const ArbuzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Арбуз',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFFE53935),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ===== ГЛАВНЫЙ ЭКРАН С ВКЛАДКАМИ =====

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _username;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _login(String username, String userId) {
    setState(() {
      _username = username;
      _userId = userId;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_username == null) {
      return LoginScreen(onLogin: _login);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍉 Арбуз'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Чаты', icon: Icon(Icons.message)),
            Tab(text: 'Группы', icon: Icon(Icons.group)),
            Tab(text: 'Каналы', icon: Icon(Icons.campaign)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () {
            setState(() { _username = null; _userId = null; });
          }),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatsList(username: _username!, userId: _userId!),
          GroupsList(username: _username!, userId: _userId!),
          ChannelsList(username: _username!, userId: _userId!),
        ],
      ),
    );
  }
}

// ===== ЭКРАН ВХОДА =====

class LoginScreen extends StatefulWidget {
  final Function(String username, String userId) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = TextEditingController();

  void _login() async {
    final username = _controller.text.trim();
    if (username.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$SERVER_URL/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      if (response.statusCode == 201 || response.statusCode == 400) {
        // Если пользователь уже есть — получаем список и ищем
        final usersResponse = await http.get(Uri.parse('$SERVER_URL/users'));
        final users = jsonDecode(usersResponse.body);
        final user = users.firstWhere((u) => u['username'] == username);
        widget.onLogin(username, user['id']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.water_drop, size: 80, color: Color(0xFF4CAF50)),
                const Text('🍉 Арбуз', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(labelText: 'Ваше имя', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                  child: const Text('Войти', style: TextStyle(color: Colors.white, fontSize: 18)),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== ЧАТЫ =====

class ChatsList extends StatelessWidget {
  final String username;
  final String userId;
  const ChatsList({super.key, required this.username, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Личные чаты — в разработке', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)));
  }
}

// ===== ГРУППЫ =====

class GroupsList extends StatefulWidget {
  final String username;
  final String userId;
  const GroupsList({super.key, required this.username, required this.userId});

  @override
  State<GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<GroupsList> {
  List _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final response = await http.get(Uri.parse('$SERVER_URL/groups'));
      setState(() => _groups = jsonDecode(response.body));
    } catch (e) {
      print('Ошибка загрузки групп: $e');
    }
  }

  void _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая группа'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Создать')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await http.post(Uri.parse('$SERVER_URL/groups'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'created_by': widget.userId}));
      _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createGroup, child: const Icon(Icons.add)),
      body: _groups.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.group_outlined, size: 80, color: Colors.grey.shade400), const SizedBox(height: 16), Text('Нет групп', style: TextStyle(color: Colors.grey.shade600))]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFF4CAF50), child: Text(group['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                    title: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(group['description'] ?? ''),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatType: 'group', chatId: group['id'], chatName: group['name'], username: widget.username, userId: widget.userId))),
                  ),
                );
              },
            ),
    );
  }
}

// ===== КАНАЛЫ =====

class ChannelsList extends StatefulWidget {
  final String username;
  final String userId;
  const ChannelsList({super.key, required this.username, required this.userId});

  @override
  State<ChannelsList> createState() => _ChannelsListState();
}

class _ChannelsListState extends State<ChannelsList> {
  List _channels = [];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final response = await http.get(Uri.parse('$SERVER_URL/channels'));
      setState(() => _channels = jsonDecode(response.body));
    } catch (e) {
      print('Ошибка загрузки каналов: $e');
    }
  }

  void _createChannel() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый канал'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Создать')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await http.post(Uri.parse('$SERVER_URL/channels'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'created_by': widget.userId}));
      _loadChannels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: _createChannel, child: const Icon(Icons.add)),
      body: _channels.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade400), const SizedBox(height: 16), Text('Нет каналов', style: TextStyle(color: Colors.grey.shade600))]))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _channels.length,
              itemBuilder: (context, index) {
                final channel = _channels[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFFE53935), child: Text(channel['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                    title: Text(channel['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Подписчиков: ${(channel['subscribers'] as List?)?.length ?? 0}'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatType: 'channel', chatId: channel['id'], chatName: channel['name'], username: widget.username, userId: widget.userId))),
                  ),
                );
              },
            ),
    );
  }
}

// ===== ЭКРАН ЧАТА (общий для групп и каналов) =====

class ChatScreen extends StatefulWidget {
  final String chatType; // group или channel
  final String chatId;
  final String chatName;
  final String username;
  final String userId;

  const ChatScreen({super.key, required this.chatType, required this.chatId, required this.chatName, required this.username, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List _messages = [];
  final _textController = TextEditingController();
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    if (widget.chatType == 'channel') {
      _checkCreator();
    }
  }

  Future<void> _checkCreator() async {
    try {
      final response = await http.get(Uri.parse('$SERVER_URL/channels'));
      final channels = jsonDecode(response.body);
      final channel = channels.firstWhere((ch) => ch['id'] == widget.chatId, orElse: () => null);
      if (channel != null) {
        setState(() => _isCreator = channel['created_by'] == widget.userId);
      }
    } catch (e) {
      print('Ошибка проверки создателя: $e');
    }
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.get(Uri.parse('$SERVER_URL/messages/${widget.chatType}/${widget.chatId}'));
      setState(() => _messages = jsonDecode(response.body));
    } catch (e) {
      print('Ошибка загрузки сообщений: $e');
    }
  }

  Future<void> _sendMessage(String text, [String? fileUrl, String? fileType]) async {
    if (widget.chatType == 'channel' && !_isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Только автор канала может писать сообщения')));
      return;
    }

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$SERVER_URL/messages'));
      request.fields['username'] = widget.username;
      request.fields['text'] = text;
      request.fields['chat_type'] = widget.chatType;
      request.fields['chat_id'] = widget.chatId;
      request.fields['user_id'] = widget.userId;
      await request.send();
      _loadMessages();
    } catch (e) {
      print('Ошибка отправки: $e');
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        var request = http.MultipartRequest('POST', Uri.parse('$SERVER_URL/messages'));
        request.fields['username'] = widget.username;
        request.fields['text'] = '';
        request.fields['chat_type'] = widget.chatType;
        request.fields['chat_id'] = widget.chatId;
        request.fields['user_id'] = widget.userId;
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
        await request.send();
        _loadMessages();
      } catch (e) {
        print('Ошибка отправки файла: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: widget.chatType == 'channel' ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
            child: Text(widget.chatName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.chatName, style: const TextStyle(fontSize: 16)),
            Text(widget.chatType == 'channel' ? 'Канал' : 'Группа', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),
        backgroundColor: widget.chatType == 'channel' ? const Color(0xFFE53935) : const Color(0xFF4CAF50),
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(child: Text('Нет сообщений', style: TextStyle(color: Colors.grey.shade600)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg['username'] == widget.username;
                    return _buildBubble(msg, isMe);
                  },
                ),
        ),
        if (widget.chatType != 'channel' || _isCreator) _buildInputBar(),
      ]),
    );
  }

  Widget _buildBubble(Map msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4CAF50) : Colors.white,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!isMe) Text(msg['username'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 12)),
            if (msg['text'] != null && msg['text'].toString().isNotEmpty) Text(msg['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            if (msg['file_url'] != null && msg['file_url'].toString().isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: msg['file_type'] == 'image'
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('$SERVER_URL${msg['file_url']}', width: 200, fit: BoxFit.cover))
                  : Chip(avatar: const Icon(Icons.attach_file, size: 18), label: Text(msg['file_type'] ?? 'Файл'))),
          ]),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(children: [
        IconButton(icon: const Icon(Icons.attach_file), onPressed: _pickAndSendFile),
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(hintText: 'Сообщение...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), filled: true, fillColor: Colors.grey.shade100),
          ),
        ),
        IconButton(icon: const Icon(Icons.send), onPressed: () {
          if (_textController.text.trim().isNotEmpty) {
            _sendMessage(_textController.text.trim());
            _textController.clear();
          }
        }),
      ]),
    );
  }
}
