import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_powerd_summaraization_tool_v1/main.dart';

void main() {
  testWidgets('Renders the initial screen correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: DocTalkApp()));

    // Verify that the AppBar title is correct.
    expect(find.text('Doc Talk'), findsOneWidget);

    // Verify that the button to pick a file is displayed.
    expect(find.text('Select PDF File'), findsOneWidget);

    // Verify that there is no progress indicator initially.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
