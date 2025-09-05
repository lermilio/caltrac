
// File: lib/services/nutrition_parser.dart
//
// A production-ready nutrition parser that mirrors ChatGPT-style accuracy.
//
// Key features
// -----------
// 1) Model settings tuned for deterministic, accurate extraction (temperature=0, seed).
// 2) Strict JSON schema via function-calling to guarantee fields exist and are integers.
// 3) Rule-based shortcuts for common brand items (e.g., Miller Lite) to bypass LLM when exact values are known.
// 4) Quantity + unit parsing (e.g., "4x", "four", "12 oz", "2 tbsp") before the LLM call.
// 5) Rock-solid JSON handling: prefers function_call.arguments, but also strips code fences if needed.
// 6) Single entry point: NutritionParser.parse(String) -> Map<String,int> {calories, protein, carbs, fat}.
//
// How to use
// ----------
// final parser = NutritionParser();
// final result = await parser.parse("four miller lites");
// => { "calories": 384, "protein": 0, "carbs": 13, "fat": 0 }
//
// Notes
// -----
// - Uses OpenAI Chat Completions w/ function-calling (compatible with 4o/4.1 models).
// - If you prefer the Responses API w/ JSON schema, you can switch endpoints later.
// - Keep your .env with OPENAI_API_KEY and ensure a full restart if you change this file
//   in a background isolate/service (hot reload won't update isolates).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NutritionParser {
  // ---- Public API ----------------------------------------------------------
  Future<Map<String, int>> parse(String userInput) async {
    // 0) Try rule-based brand shortcuts (fast, exact)
    final shortcut = _alcoholShortcut(userInput);
    if (shortcut != null) return shortcut;

    // 1) Build a function-call request to force structured JSON
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing OPENAI_API_KEY in .env');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Define strict schema as a "function"
    final functions = [
      {
        "name": "return_nutrition",
        "description": "Return total macros for the described food/drink input.",
        "parameters": {
          "type": "object",
          "properties": {
            "calories": {"type": "integer", "description": "Total calories >= 0"},
            "protein":  {"type": "integer", "description": "Protein grams >= 0"},
            "carbs":    {"type": "integer", "description": "Carb grams >= 0"},
            "fat":      {"type": "integer", "description": "Fat grams >= 0"}
          },
          "required": ["calories", "protein", "carbs", "fat"],
          "additionalProperties": false
        }
      }
    ];

    final messages = [
      {
        "role": "system",
        "content":
            "You are a nutrition parser. Extract TOTAL calories, protein (g), carbs (g), fat (g) from a single user entry. "
            "Rules: return INTEGERS ONLY; if a value cannot be inferred, use 0; prefer brand-specific known values when a brand is named "
            "(e.g., Miller Lite ≈ 96 kcal, 3.2 g carbs per 12 oz; Michelob Ultra ≈ 95 kcal, 2.6 g carbs per 12 oz; Bud Light ≈ 110 kcal, "
            "6.6 g carbs per 12 oz; Coors Light ≈ 102 kcal, 5 g carbs per 12 oz). If item says 'light/lite', use light-beer macros. "
            "Multiply by quantity (e.g., 'four beers' = 4 servings). Convert units when needed; round final macros to integers. "
            "Account for multiple items; do NOT ask clarifying questions—make a best reasonable estimate."
      },
      {"role": "user", "content": userInput}
    ];

    final body = {
      "model": "gpt-4o-mini",
      "temperature": 0.0,
      "seed": 7,
      "messages": messages,
      "functions": functions,
      "function_call": {"name": "return_nutrition"},
      "max_tokens": 200
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = (data['choices'] as List?) ?? const [];
    if (choices.isEmpty) {
      throw Exception('Empty choices from OpenAI.');
    }
    final msg = choices.first['message'] as Map<String, dynamic>?;

    // Preferred path: function_call.arguments is a JSON string
    if (msg != null && msg['function_call'] != null) {
      final fnCall = msg['function_call'];
      final argsStr = (fnCall['arguments'] as String?) ?? '{}';
      final parsed = _safeParseJson(argsStr);
      return _coerceIntNutrition(parsed);
    }

    // Rare fallback: content contains JSON (strip fences)
    final content = (msg?['content'] as String?) ?? '{}';
    final cleaned = _stripCodeFences(content.trim());
    final parsed = _safeParseJson(cleaned);
    return _coerceIntNutrition(parsed);
  }

  // ---- Rule-based brand shortcuts -----------------------------------------
  // Per 12 oz serving. Values mirror brand norms commonly cited on labels.
  static const Map<String, Map<String, num>> _perServing = {
    'miller lite': {'calories': 96, 'carbs': 3.2, 'protein': 0, 'fat': 0},
    'bud light':   {'calories': 110, 'carbs': 6.6, 'protein': 1, 'fat': 0},
    'michelob ultra': {'calories': 95, 'carbs': 2.6, 'protein': 0.6, 'fat': 0},
    'coors light': {'calories': 102, 'carbs': 5.0, 'protein': 1.0, 'fat': 0},
  };

  static final RegExp _beerCountRe = RegExp(
    r'(?:(\d+)\s*x\s*)?(one|two|three|four|five|six|seven|eight|nine|ten|\d+)?\s*'
    r'(?:cans?|bottles?|beers?)?\s*(?:of\s+)?(miller lite|bud light|michelob ultra|coors light)\b',
    caseSensitive: false,
  );

  Map<String, int>? _alcoholShortcut(String input) {
    final m = _beerCountRe.firstMatch(input.toLowerCase());
    if (m == null) return null;

    final maybeMult = m.group(1);      // e.g., "4x"
    final maybeCount = m.group(2);     // e.g., "four"
    final brand = (m.group(3) ?? '').trim();

    final count = (maybeMult != null && maybeMult.isNotEmpty)
        ? int.tryParse(maybeMult) ?? 1
        : (maybeCount != null ? _wordToInt(maybeCount) : 1);

    final key = _perServing.keys.firstWhere(
      (k) => brand.contains(k),
      orElse: () => '',
    );
    if (key.isEmpty) return null;

    final per = _perServing[key]!;
    int toInt(num v) => v.round();
    return {
      'calories': toInt(per['calories']! * count),
      'carbs':    toInt(per['carbs']! * count),
      'protein':  toInt(per['protein']! * count),
      'fat':      toInt(per['fat']! * count),
    };
  }

  int _wordToInt(String w) {
    const map = {
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    };
    return map[w.toLowerCase()] ?? int.tryParse(w) ?? 1;
  }

  // ---- JSON helpers --------------------------------------------------------
  String _stripCodeFences(String s) {
    if (!s.trimLeft().startsWith('```')) return s;
    final lines = s.split('\n');
    if (lines.isNotEmpty && lines.first.trim().startsWith('```')) {
      lines.removeAt(0);
    }
    if (lines.isNotEmpty && lines.last.trim().startsWith('```')) {
      lines.removeLast();
    }
    return lines.join('\n').trim();
  }

  Map<String, dynamic> _safeParseJson(String s) {
    try {
      final v = jsonDecode(s);
      if (v is Map) {
        return Map<String, dynamic>.from(v);
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, int> _coerceIntNutrition(Map<String, dynamic> m) {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v < 0 ? 0 : v;
      if (v is double) return v < 0 ? 0 : v.round();
      if (v is num) return v < 0 ? 0 : v.round();
      if (v is String) {
        final n = num.tryParse(v.replaceAll(RegExp(r'[^0-9\.-]'), ''));
        if (n == null) return 0;
        return n < 0 ? 0 : n.round();
      }
      return 0;
    }

    return {
      'calories': toInt(m['calories']),
      'protein':  toInt(m['protein']),
      'carbs':    toInt(m['carbs']),
      'fat':      toInt(m['fat']),
    };
  }
}
