/*
 * This Flutter example demonstrates how you can integrate the DeepSeek‑OCR
 * model into a mobile application.  The application allows the user to
 * select a PDF file (or Word/PowerPoint after converting to PDF),
 * renders each page to an image and sends it to the DeepSeek‑OCR API.
 * The responses for every page are collected in a list of maps and
 * finally written to a JSON file in the application documents directory.
 * You could then feed that JSON into a chat model (e.g. DeepSeek‑Chat)
 * to ask questions about the document.
 */

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepSeek OCR Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isProcessing = false;
  List<Map<String, dynamic>> _results = [];
  String? _errorMessage;

  // TODO: Replace this with your own API key obtained from DeepInfra or another provider.
  static const String apiKey = 'sk-ef3722c934ab419e82c90c479644168e';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepSeek OCR Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isProcessing ? null : _pickAndProcessFile,
              child: const Text('اختر ملف PDF أو Word أو PowerPoint'),
            ),
            const SizedBox(height: 16),
            if (_isProcessing) const CircularProgressIndicator(),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    title: Text('صفحة ${result['page']}'),
                    subtitle: Text(result['text'] as String),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndProcessFile() async {
    setState(() {
      _errorMessage = null;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx'],
    );
    if (result == null || result.files.single.path == null) {
      return;
    }
    final filePath = result.files.single.path!;
    final ext = path.extension(filePath).toLowerCase();
    setState(() {
      _isProcessing = true;
      _results = [];
    });
    try {
      if (ext == '.pdf') {
        await _processPdf(filePath);
      } else {
        // For Word and PowerPoint files, convert them to PDF first using an external
        // service or a backend before processing.
        setState(() {
          _errorMessage = 'تم اختيار ملف $ext. يرجى تحويله إلى PDF أولاً.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء المعالجة: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPdf(String filePath) async {
    final document = await PdfDocument.openFile(filePath);
    final int pageCount = document.pagesCount;
    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final renderedPage = await page.render(width: page.width, height: page.height);
      if (renderedPage != null) {
        final bytes = renderedPage.bytes;
        final base64Image = base64Encode(bytes);
        final text = await _callOcrApi(base64Image);
        setState(() {
          _results.add({'page': i, 'text': text});
        });
      }
      await page.close();
    }
    await document.close();
    final directory = await getApplicationDocumentsDirectory();
    final jsonFile = File(path.join(directory.path, 'ocr_results.json'));
    final jsonString = jsonEncode(_results);
    await jsonFile.writeAsString(jsonString);
  }

  Future<String> _callOcrApi(String base64Image) async {
    const String endpoint =
        'https://api.deepinfra.com/v1/openai/chat/completions';
    final Map<String, dynamic> body = {
      'model': 'deepseek-ai/DeepSeek-OCR',
      'max_tokens': 4092,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,$base64Image',
              },
            },
            {
              'type': 'text',
              // Using the "Free OCR." prompt to extract all text without layout
              'text': 'Free OCR.',
            },
          ],
        },
      ],
    };
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      final String content = jsonResponse['choices'][0]['message']['content'];
      return content;
    } else {
      throw Exception('API returned ${response.statusCode}: ${response.body}');
    }
  }
}
