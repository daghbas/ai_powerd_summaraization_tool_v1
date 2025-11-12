// lib/widgets/message_renderer.dart
import 'package:flutter/material.dart';
import 'dart:math';

class MessageRenderer extends StatelessWidget {
  final String content;
  final bool isRTL;

  const MessageRenderer({
    super.key,
    required this.content,
    required this.isRTL,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseContent(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: segments.map((segment) => _buildSegment(segment, context)).toList(),
    );
  }

  List<ContentSegment> _parseContent(String content) {
    final segments = <ContentSegment>[];
    final lines = content.split('\n');
    int titleCounter = 0;

    for (final line in lines) {
      String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      if (trimmedLine.startsWith('# ')) {
        titleCounter++;
        segments.add(ContentSegment(
          type: SegmentType.title,
          text: trimmedLine.substring(2).replaceAll('**', ''),
          number: titleCounter,
        ));
      } else if (trimmedLine.startsWith('## ')) {
        segments.add(ContentSegment(
          type: SegmentType.subtitle,
          text: trimmedLine.substring(3).replaceAll('**', ''),
        ));
      } else if (trimmedLine.startsWith('*') || trimmedLine.startsWith('-')) {
        segments.add(ContentSegment(
          type: SegmentType.bullet,
          text: trimmedLine.substring(1).trim(),
        ));
      } else {
        segments.add(ContentSegment(
          type: SegmentType.paragraph,
          text: trimmedLine,
        ));
      }
    }

    return segments;
  }

  Widget _buildSegment(ContentSegment segment, BuildContext context) {
    switch (segment.type) {
      case SegmentType.title:
        return _buildTitle(segment.text, context, segment.number!);
      case SegmentType.subtitle:
        return _buildSubtitle(segment.text, context);
      case SegmentType.paragraph:
        return _buildParagraph(segment.text, context);
      case SegmentType.bullet:
        return _buildBullet(segment.text, context);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTitle(String text, BuildContext context, int number) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue[800], 
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildRichText(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4, left: 16), // Indent subtitles
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRichText(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: _buildRichText(text, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
    );
  }

  Widget _buildBullet(String text, BuildContext context) {
    final bulletStyle = ['•', '◦', '▪'][Random().nextInt(3)];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$bulletStyle ', style: TextStyle(fontSize: 14, color: Colors.blue[800], fontWeight: FontWeight.bold)),
          Expanded(
            child: _buildRichText(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  RichText _buildRichText(String text, {required TextStyle style}) {
    List<TextSpan> spans = [];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) { // Bold text
        spans.add(TextSpan(text: parts[i], style: style.copyWith(fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: parts[i], style: style));
      }
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: isRTL ? TextAlign.right : TextAlign.left,
    );
  }
}


class ContentSegment {
  final SegmentType type;
  final String text;
  final int? number;

  const ContentSegment({
    required this.type,
    this.text = '',
    this.number,
  });
}

enum SegmentType {
  title,
  subtitle,
  paragraph,
  bullet,
}