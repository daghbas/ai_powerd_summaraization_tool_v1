import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../services/gemini_service.dart';
import '../services/database.dart'; // Import database
import '../pages/chat_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  File? _selectedFile;
  double _progress = 0.0;
  String _progressMessage = '';
  String? _summary;
  bool _isProcessing = false;
  String? _error;
  Map<String, dynamic>? _extractedData;

  Future<void> _pickFile() async {
    // ... (omitting unchanged code for brevity)
  }

  Future<void> _processDocument() async {
    final file = _selectedFile;
    if (file == null) return;
    final service = ref.read(geminiServiceProvider);
    final db = ref.read(databaseProvider); // Read database provider

    setState(() {
      _isProcessing = true;
      _error = null;
      _summary = null;
      _extractedData = null;
    });

    try {
      // 1. Upload PDF
      _updateProgress(0.0, 'Uploading document...');
      final uri = await service.uploadPdf(file);
      if (uri == null) {
        throw Exception('Upload failed. Please check your network and API key.');
      }
      _updateProgress(0.3, 'Document uploaded successfully.');

      // Create session in DB
      final sessionId = await db.createSession(file.path.split('/').last, uri);

      // 2. Extract structured content
      _updateProgress(0.3, 'Extracting text and structure...');
      final extracted = await service.extractStructured(uri);
      setState(() {
        _extractedData = extracted;
      });
      _updateProgress(0.7, 'Content extraction complete.');

      // 3. Generate summary
      _updateProgress(0.7, 'Generating summary...');
      final summary = await service.askQuestion(
        uri,
        'Briefly summarize the document, highlighting the main points. Use Arabic if the document is in Arabic, otherwise use English.',
      );
      _updateProgress(1.0, 'Processing complete!');
      setState(() {
        _summary = summary.trim();
        _isProcessing = false;

        // Navigate to ChatPage with the new session ID
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(sessionId: sessionId, initialContent: extracted),
          ),
        );
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
        _progress = 0.0;
        _progressMessage = '';
      });
    }
  }

  void _updateProgress(double value, String message) {
     // ... (omitting unchanged code for brevity)
  }
  
  String _getExtractedTextPreview() {
     // ... (omitting unchanged code for brevity)
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The rest of the build method remains largely the same,
    // but the final navigation is now handled within _processDocument.
    // I will omit the full build method here for brevity as the logic change was the important part.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doc Talk (Legacy)'),
      ),
       body: Center(child: Text("This page is deprecated. Please use the Upload tab.")),
    );
  }
}
