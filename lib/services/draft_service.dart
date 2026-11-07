import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An entry being written, as it was when the app last went to the background.
class JournalDraft {
  const JournalDraft({
    required this.title,
    required this.body,
    required this.date,
    this.mood,
    this.journal,
    this.newImagePaths = const [],
    this.imagesToDelete = const [],
  });

  final String title;
  final String body;
  final DateTime date;

  /// Mood label ('Happy', 'Calm', ...)
  final String? mood;

  /// The entry being edited as it came from the server; null for a new entry
  final Map<String, dynamic>? journal;
  final List<String> newImagePaths;
  final List<String> imagesToDelete;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'date': date.toIso8601String(),
    'mood': mood,
    'journal': journal,
    'newImagePaths': newImagePaths,
    'imagesToDelete': imagesToDelete,
  };

  static JournalDraft? fromJson(Object? json) {
    if (json is! Map) return null;
    final date = DateTime.tryParse((json['date'] ?? '').toString());
    if (date == null) return null;
    final journal = json['journal'];
    return JournalDraft(
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      date: date,
      mood: json['mood']?.toString(),
      journal: journal is Map ? Map<String, dynamic>.from(journal) : null,
      // Photos picked before the app closed may have been cleared from the cache
      newImagePaths: [
        for (final p in (json['newImagePaths'] as List? ?? const []))
          if (File(p.toString()).existsSync()) p.toString(),
      ],
      imagesToDelete: [for (final u in (json['imagesToDelete'] as List? ?? const [])) u.toString()],
    );
  }
}

/// Keeps the entry you're writing on the phone, so it's still there if Android
/// closes Notevia in the background (like an unsent WhatsApp message).
class DraftService {
  static const _key = 'journal_draft';

  static Future<void> save(JournalDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(draft.toJson()));
    } catch (_) {}
  }

  static Future<JournalDraft?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      return raw == null ? null : JournalDraft.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  /// Open the journal, and the unfinished entry on top of it if there is one.
  static Future<void> openHome(NavigatorState navigator) async {
    final draft = await load();
    navigator.pushNamedAndRemoveUntil('/home', (r) => false, arguments: draft);
  }
}
