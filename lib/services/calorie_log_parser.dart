import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<Map<String, dynamic>> extractNutrition(String userInput) async {
  final apiKey = dotenv.env['OPENAI_API_KEY'];
  final url = Uri.parse('https://api.openai.com/v1/chat/completions');

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content": "You are a nutrition logging assistant. The user may enter either full food descriptions (e.g. '10oz grilled chicken breast') or manual data (e.g. '1000 calories, 100g protein'). Extract calories, protein, carbs, and fat. Always return JSON like: {\"calories\":123,\"protein\":30,\"carbs\":10,\"fat\":5}. If any value is missing, use 0."
        },
        {
          "role": "user",
          "content": userInput,
        },
      ],
      "temperature": 0.2,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'];
    return jsonDecode(content);
  } else {
    throw Exception('OpenAI error: ${response.body}');
  }
}