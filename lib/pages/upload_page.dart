// lib/pages/upload_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/gemini_service.dart';
import '../services/database.dart';
import 'chat_page.dart';
import 'dart:async';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  File? _selectedFile;
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  List<String> _extractedSnippets = [];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _isProcessing = false;
        _progress = 0.0;
        _statusMessage = '';
        _extractedSnippets = [];
      });
    }
  }

  Future<void> _processDocument() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _extractedSnippets = [];
    });

    try {
      final service = ref.read(geminiServiceProvider);
      final db = ref.read(databaseProvider);

      // Stage 1: Upload (0% -> 25%)
      _updateProgress(0.0, 'Uploading document...');
      final fileUri = await service.uploadPdf(_selectedFile!);
      if (fileUri == null) throw Exception('File upload failed.');
      _updateProgress(0.25, 'Document uploaded. Creating session...');

      // Create a new chat session in the database
      final title = _selectedFile!.path.split('/').last;
      final sessionId = await db.createSession(title, fileUri);

      // Stage 2: Extract Content (25% -> 75%)
      await Future.delayed(const Duration(milliseconds: 500));
      _updateProgress(0.4, 'Extracting key sections...');
      final extracted = await service.extractStructured(fileUri, mode: 'fast');
      
      // Show snippets progressively
      final pages = extracted['pages'] as List?;
      if (pages != null) {
        for (final page in pages) {
          final items = page['items'] as List?;
          if (items != null) {
            for (final item in items) {
              final text = item['text'] as String? ?? '';
              if (text.trim().isNotEmpty) {
                setState(() {
                  _extractedSnippets.add('📄 [Page ${page['page']}] ${text.length > 50 ? text.substring(0, 50) : text}...');
                });
                await Future.delayed(const Duration(milliseconds: 100)); 
              }
            }
          }
        }
      }
      _updateProgress(0.75, 'Content extraction complete.');

      // Stage 3: Navigate (75% -> 100%)
      await Future.delayed(const Duration(milliseconds: 500));
      _updateProgress(1.0, 'Done! Opening chat...');
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatPage(sessionId: sessionId, initialContent: extracted),
          ),
        ).then((_) => _resetState());
      }

    } catch (e) {
      setState(() {
        _statusMessage = 'An error occurred: $e';
        _isProcessing = false;
      });
    }
  }

  void _updateProgress(double value, String message) {
    setState(() {
      _progress = value;
      _statusMessage = message;
    });
  }

  void _resetState() {
     setState(() {
        _selectedFile = null;
        _isProcessing = false;
        _progress = 0.0;
        _statusMessage = '';
        _extractedSnippets = [];
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description, size: 40, color: _selectedFile != null ? Theme.of(context).primaryColor : Colors.grey),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _selectedFile?.path.split('/').last ?? 'Select a PDF file to get started',
                            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isProcessing) 
                  _buildProgressSection()
                else if (_statusMessage.isNotEmpty && !_isProcessing)
                  _buildErrorSection(),
              ],
            ),
            
            ElevatedButton(
              onPressed: _selectedFile != null && !_isProcessing ? _processDocument : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isProcessing ? 'Processing...' : 'Start Processing',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(_statusMessage, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 16),
        if (_extractedSnippets.isNotEmpty)
          Container(
            height: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _extractedSnippets.length,
              itemBuilder: (context, index) => Text(_extractedSnippets[index],
                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(child: Text(_statusMessage, style: TextStyle(color: Colors.red[800]))),
        ],
      ),
    );
  }
}
