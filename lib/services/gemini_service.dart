// lib/services/gemini_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';

class GeminiService {
  GeminiService();

  // Updated to use the correct model name
  static final String _model = dotenv.env['GEMINI_MODEL'] ?? 'gemini-1.5-pro';

  // تحسين رفع الملفات مع تتبع التقدم
  Future<String?> uploadPdf(File pdf, {void Function(int, int)? onProgress}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final filesEndpoint = dotenv.env['GEMINI_FILES_ENDPOINT'];
    if (apiKey == null || filesEndpoint == null) {
      throw Exception('GEMINI_API_KEY or GEMINI_FILES_ENDPOINT not configured');
    }

    final request = http.MultipartRequest('POST', Uri.parse('$filesEndpoint?key=$apiKey'));
    final file = await http.MultipartFile.fromPath('file', pdf.path,
        contentType: MediaType('application', 'pdf'));
    
    request.files.add(file);

    final response = await request.send();
    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['file']?['uri'] as String?;
    } else {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Failed to upload: ${response.statusCode} $errorBody');
    }
  }

  // استخراج محتوى سريع مع خيارات متعددة
  Future<Map<String, dynamic>> extractStructured(String fileUri, {String mode = 'fast'}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final endpoint = dotenv.env['GEMINI_GENERATE_ENDPOINT'];
    if (apiKey == null || endpoint == null) {
      throw Exception('GEMINI_API_KEY or GEMINI_GENERATE_ENDPOINT not configured');
    }

    // اختيار prompt بناءً على mode
    String prompt;
    switch (mode) {
      case 'detailed':
        prompt = _extractionPromptDetailed;
      case 'academic':
        prompt = _extractionPromptAcademic;
      case 'fast':
      default:
        prompt = _extractionPromptFast;
    }

    final payload = {
      'contents': [
        {
          'parts': [
            {
              'fileData': {'mimeType': 'application/pdf', 'fileUri': fileUri}
            },
            {'text': prompt},
          ]
        }
      ],
      'tools': [
        {
          'functionDeclarations': [
            {
              'name': 'extract_document_content',
              'description': 'Extracts structured content from the document.',
              'parameters': _schema,
            }
          ]
        }
      ],
      'toolConfig': {
        'functionCallingConfig': {
          'mode': 'ANY',
          'allowedFunctionNames': ['extract_document_content']
        }
      },
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': mode == 'fast' ? 4096 : 8192,
      }
    };

    final url = Uri.parse('$endpoint/$_model:generateContent?key=$apiKey');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200) {
      final jsonResponse = jsonDecode(resp.body) as Map<String, dynamic>;
      final functionCallPart = jsonResponse['candidates']?[0]?['content']?['parts']
          ?.firstWhere((part) => part['functionCall'] != null, orElse: () => null);
      if (functionCallPart != null) {
        final functionCall = functionCallPart['functionCall'];
        if (functionCall['name'] == 'extract_document_content') {
          return functionCall['args'] as Map<String, dynamic>;
        }
      }
      return {};
    } else {
      throw Exception('Failed to extract: ${resp.statusCode} ${resp.body}');
    }
  }

  Stream<String> askQuestionStream(String fileUri, String question) async* {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final endpoint = dotenv.env['GEMINI_GENERATE_ENDPOINT'];
    if (apiKey == null || endpoint == null) {
      throw Exception('GEMINI_API_KEY or GEMINI_GENERATE_ENDPOINT not configured');
    }
    final content = [
      {
        'parts': [
          {
            'fileData': {'mimeType': 'application/pdf', 'fileUri': fileUri}
          },
          {
            'text': 'Answer the following question based only on the content of the attached PDF. Cite page numbers for any facts. If the information is absent, say so.'
          },
          {'text': question},
        ]
      }
    ];
    final payload = {
      'contents': content,
    };

    final url = Uri.parse('$endpoint/$_model:streamGenerateContent?alt=sse&key=$apiKey');
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(payload);

    final client = http.Client();
    final response = await client.send(request);

    try {
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonString = line.substring(6);
            if (jsonString.isNotEmpty) {
              final json = jsonDecode(jsonString);
              final text = json?['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
              if (text != null) {
                yield text;
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }
   Future<String> askQuestion(String fileUri, String question) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final endpoint = dotenv.env['GEMINI_GENERATE_ENDPOINT'];
    if (apiKey == null || endpoint == null) {
      throw Exception('GEMINI_API_KEY or GEMINI_GENERATE_ENDPOINT not configured');
    }
    final content = [
      {
        'parts': [
          {
            'fileData': {'mimeType': 'application/pdf', 'fileUri': fileUri}
          },
          {
            'text': 'Answer the following question based only on the content of the attached PDF. Cite page numbers for any facts. If the information is absent, say so.'
          },
          {'text': question},
        ]
      }
    ];
    final payload = {
      'contents': content,
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 2048,
      },
    };
    final url = Uri.parse('$endpoint/$_model:generateContent?key=$apiKey');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String? ?? '';
    }
    throw Exception('Failed to ask question: ${resp.statusCode} ${resp.body}');
  }

  static const String _extractionPromptFast =
      'استخرج العناوين الرئيسية والعناوين الفرعية والنقاط المهمة فقط من المستند. ركز على المعلومات الأساسية مع ذكر أرقام الصفحات. استخدم اللغة العربية للنتائج.';

  static const String _extractionPromptDetailed =
      'استخرج المحتوى الكامل من المستند بدقة عالية بما في ذلك العناوين والفقرات والجداول والأشكال. اذكر أرقام الصفحات لكل عنصر. نظم المخرجات بطريقة هرمية.';

  static const String _extractionPromptAcademic =
      'استخرج المعلومات الأكاديمية المهمة مثل النظريات والتعريفات والأمثلة والاستنتاجات. ركز على المحتوى التعليمي مع التنظيم المنطقي وذكر أرقام الصفحات.';

  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'doc_id': {'type': 'string'},
      'pages': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'page': {'type': 'integer'},
            'items': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': ['heading', 'paragraph', 'table', 'figure']
                  },
                  'text': {'type': 'string'},
                  'markdown': {'type': 'string'},
                  'csv': {'type': 'string'},
                  'caption': {'type': 'string'},
                  'bbox': {
                    'type': 'array',
                    'items': {'type': 'number'},
                    'minItems': 4,
                    'maxItems': 4
                  }
                },
                'required': ['type']
              }
            }
          },
          'required': ['page', 'items']
        }
      }
    },
    'required': ['doc_id', 'pages']
  };
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
