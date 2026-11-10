// Requests nutrition estimates, validates their shape and numeric values, and
// returns whole-number calories and macros. Validation does not prove accuracy.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NutritionParseException implements Exception {
  const NutritionParseException();

  @override
  String toString() => 'Could not read nutrition data. Please try again.';
}

class NutritionParser {
  NutritionParser({http.Client? client}) : _client = client;

  // A supplied client belongs to the caller. Otherwise each request owns its client.
  final http.Client? _client;

  // ---- Public API ----------------------------------------------------------
  Future<Map<String, int>> parse(String userInput) async {
    // Request structured JSON; the response still needs local validation.
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Missing OPENAI_API_KEY in .env');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    // Describe the expected nutrition fields as a function.
    final functions = [
      {
        "name": "return_nutrition",
        "description":
            "Return total macros for the described food or drink input.",
        "parameters": {
          "type": "object",
          "properties": {
            "calories": {
              "type": "integer",
              "description": "Total calories >= 0",
            },
            "protein": {"type": "integer", "description": "Protein grams >= 0"},
            "carbs": {"type": "integer", "description": "Carb grams >= 0"},
            "fat": {"type": "integer", "description": "Fat grams >= 0"},
          },
          "required": ["calories", "protein", "carbs", "fat"],
          "additionalProperties": false,
        },
      },
    ];

    final messages = [
      {
        "role": "system",
        "content":
            "You are a nutrition parser. Extract TOTAL calories, protein (g), carbs (g), fat (g) from a single user entry. "
            "Rules: return INTEGERS ONLY; if a value cannot be inferred, use 0. "
            "Use sensible, real-world estimates based on typical foods and drinks (e.g., restaurant meals, snacks, soft drinks, coffee drinks, protein shakes). "
            "Multiply by quantity when the user gives counts, package sizes, or weights. "
            "Account for multiple items; do NOT ask clarifying questions—make a best reasonable estimate.",
      },
      {"role": "user", "content": userInput},
    ];

    final body = {
      "model": "gpt-4o-mini",
      "temperature": 0.0,
      "seed": 7,
      "messages": messages,
      "functions": functions,
      "function_call": {"name": "return_nutrition"},
      "max_tokens": 200,
    };

    final client = _client ?? http.Client();
    late http.Response response;
    try {
      response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(body),
      );
    } finally {
      if (_client == null) client.close();
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Nutrition service request failed (${response.statusCode}). Please try again.',
      );
    }

    final data = _decodeObject(response.body);
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const NutritionParseException();
    }
    final choice = choices.first as Map;
    final msg = choice['message'];
    if (msg is! Map || choice['finish_reason'] == 'length') {
      throw const NutritionParseException();
    }

    // Preferred path: function_call.arguments is a JSON string
    if (msg['function_call'] != null) {
      final fnCall = msg['function_call'];
      if (fnCall is! Map ||
          fnCall['name'] != 'return_nutrition' ||
          fnCall['arguments'] is! String) {
        throw const NutritionParseException();
      }
      return _validateNutrition(_decodeObject(fnCall['arguments'] as String));
    }

    // Rare fallback: content contains JSON (strip fences)
    final content = msg['content'];
    if (content is! String) throw const NutritionParseException();
    return _validateNutrition(_decodeObject(_stripCodeFences(content)));
  }

  // ---- JSON helpers --------------------------------------------------------
  String _stripCodeFences(String s) {
    s = s.trim();
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

  Map<String, dynamic> _decodeObject(String s) {
    try {
      final value = jsonDecode(s);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      throw const NutritionParseException();
    }
    throw const NutritionParseException();
  }

  Map<String, int> _validateNutrition(Map<String, dynamic> values) {
    final nutrition = <String, int>{};
    for (final field in ['calories', 'protein', 'carbs', 'fat']) {
      final value = values[field];
      if (value is! num || !value.isFinite || value < 0) {
        throw const NutritionParseException();
      }
      nutrition[field] = value.round();
    }
    return nutrition;
  }
}
