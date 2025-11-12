import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
import 'package:flutter_riverpod/legacy.dart';
import '../services/gemini_service.dart';
import '../services/database.dart';
import '../widgets/message_renderer.dart';

// Renamed to avoid conflict with Drift's ChatMessage
class UIMessage {
  final MessageRole role;
  String content;
  final DateTime timestamp;
  bool isStreaming;

  UIMessage({required this.role, required this.content, required this.timestamp, this.isStreaming = false});

  factory UIMessage.fromDb(ChatMessage data) {
    return UIMessage(
      role: data.role == 'user' ? MessageRole.user : MessageRole.assistant,
      content: data.content,
      timestamp: data.timestamp,
    );
  }

  factory UIMessage.fromUserInput(String content) {
    return UIMessage(role: MessageRole.user, content: content, timestamp: DateTime.now());
  }

  factory UIMessage.streamingAssistant() {
    return UIMessage(role: MessageRole.assistant, content: '', timestamp: DateTime.now(), isStreaming: true);
  }

  factory UIMessage.fromError(String error) {
    return UIMessage(role: MessageRole.assistant, content: error, timestamp: DateTime.now());
  }
}

enum MessageRole { user, assistant }

// Provider to manage the current language
final languageProvider = StateProvider<AppLanguage>((ref) => AppLanguage.arabic);

enum AppLanguage { arabic, english }

class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;
  final Map<String, dynamic>? initialContent;

  const ChatPage({super.key, required this.sessionId, this.initialContent});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<UIMessage> _messages = [];
  bool _isSending = false;
  final _scrollController = ScrollController();
  String _fileUri = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final db = ref.read(databaseProvider);
    final session = await (db.select(db.chatSessions)..where((tbl) => tbl.id.equals(widget.sessionId))).getSingleOrNull();

    if (session == null) {
      setState(() {
        _isLoading = false;
        _messages.add(UIMessage.fromError('Session not found!'));
      });
      return;
    }

    _fileUri = session.fileUri;
    final historicMessages = await db.getMessages(widget.sessionId);

    if (historicMessages.isEmpty && widget.initialContent != null) {
      final summary = _generateSummary(widget.initialContent!, AppLanguage.arabic);
      await db.addMessage(widget.sessionId, 'assistant', summary);
      final firstMsg = await db.getMessages(widget.sessionId).then((list) => list.first);
       _messages.add(UIMessage.fromDb(firstMsg));
    } else {
      _messages.addAll(historicMessages.map(UIMessage.fromDb));
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _generateSummary(Map<String, dynamic> content, AppLanguage language) {
     // ... (omitting unchanged code for brevity)
    return '';
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final db = ref.read(databaseProvider);
    await db.addMessage(widget.sessionId, 'user', text);

    setState(() {
      _messages.add(UIMessage.fromUserInput(text));
      _controller.clear();
      _isSending = true;
      _messages.add(UIMessage.streamingAssistant());
    });

    try {
      final service = ref.read(geminiServiceProvider);
      final stream = service.askQuestionStream(_fileUri, text);
      
      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
        setState(() {
          _messages.last.content = fullResponse;
        });
      }
      
      await db.addMessage(widget.sessionId, 'assistant', fullResponse);
      final savedMessage = await (db.select(db.chatMessages)..where((tbl) => tbl.sessionId.equals(widget.sessionId))..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])).getSingle();

      setState(() {
        _messages.removeLast();
        _messages.add(UIMessage.fromDb(savedMessage));
        _isSending = false;
      });

    } catch (e) {
      final errorMessage = '❌ An error occurred: $e';
      await db.addMessage(widget.sessionId, 'assistant', errorMessage);
       setState(() {
        _messages.last.content = errorMessage;
        _messages.last.isStreaming = false;
        _isSending = false;
      });
    }
  }

   void _toggleLanguage() {
    ref.read(languageProvider.notifier).state = 
      ref.read(languageProvider) == AppLanguage.arabic ? AppLanguage.english : AppLanguage.arabic;
  }

  void _showQuickQuestions() {
    // ... (omitting unchanged code for brevity)
  }

  List<String> _getQuickQuestions(AppLanguage language) {
    // ... (omitting unchanged code for brevity)
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(languageProvider);
    final isRTL = currentLanguage == AppLanguage.arabic;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar( /* ... */ ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) => ChatMessageBubble(message: _messages[index], isRTL: isRTL),
                    ),
                  ),
                  // ... Input Area ...
                ],
              ),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  final UIMessage message;
  final bool isRTL;

  const ChatMessageBubble({super.key, required this.message, required this.isRTL});

   @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MessageRenderer(content: message.content, isRTL: isRTL),
                  if (message.isStreaming)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
