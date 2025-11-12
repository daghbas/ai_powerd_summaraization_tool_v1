import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

// Define tables
class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get fileUri => text()(); // Added to store file URI
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sessionId => text().references(ChatSessions, #id)();
  TextColumn get role => text()(); // 'user' or 'assistant'
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime()();
}

@DriftDatabase(tables: [ChatSessions, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Methods to interact with the database
  Future<String> createSession(String title, String fileUri) async {
    final id = Uuid().v4();
    await into(chatSessions).insert(ChatSessionsCompanion.insert(
      id: id,
      title: title,
      fileUri: fileUri,
      createdAt: DateTime.now(),
    ));
    return id;
  }

  Future<void> addMessage(String sessionId, String role, String content) async {
    await into(chatMessages).insert(ChatMessagesCompanion.insert(
      sessionId: sessionId,
      role: role,
      content: content,
      timestamp: DateTime.now(),
    ));
  }

  Future<List<ChatMessage>> getMessages(String sessionId) {
    return (select(chatMessages)..where((tbl) => tbl.sessionId.equals(sessionId))).get();
  }

  Stream<List<ChatSession>> watchSessions(String query) {
    final likeQuery = '%$query%';
    return (select(chatSessions)..where((tbl) => tbl.title.like(likeQuery))..orderBy([ (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])).watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

// Provider for the database
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
