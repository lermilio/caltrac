import 'dart:convert';

import 'package:caltrac/screens/log_screen.dart';
import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const nutrition = {'calories': 200, 'protein': 30, 'carbs': 5, 'fat': 7};

String responseForMessage(
  Map<String, dynamic> message, {
  String finishReason = 'stop',
}) => jsonEncode({
  'choices': [
    {'message': message, 'finish_reason': finishReason},
  ],
});

String responseForArguments(String arguments) => responseForMessage({
  'function_call': {'name': 'return_nutrition', 'arguments': arguments},
});

Future<Map<String, int>> parseResponse(String body, {int status = 200}) async {
  final client = MockClient((_) async => http.Response(body, status));
  try {
    return await NutritionParser(client: client).parse('Chicken breast');
  } finally {
    client.close();
  }
}

void main() {
  setUp(() {
    // No real .env file or credentials are loaded by these tests.
    dotenv.testLoad(fileInput: 'OPENAI_API_KEY=dummy-test-key');
  });

  test(
    'valid function arguments return nutrition and preserve the request input',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/chat/completions');
        expect(request.headers['Authorization'], 'Bearer dummy-test-key');
        final body = jsonDecode(request.body) as Map;
        expect(body['messages'].last['content'], 'Chicken breast');
        return http.Response(responseForArguments(jsonEncode(nutrition)), 200);
      });
      addTearDown(client.close);
      expect(
        await NutritionParser(client: client).parse('Chicken breast'),
        nutrition,
      );
    },
  );

  test('explicit zeros remain valid nutrition', () async {
    const zeros = {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
    expect(await parseResponse(responseForArguments(jsonEncode(zeros))), zeros);
  });

  test('finite nonnegative decimals still round to whole numbers', () async {
    final values = {
      'calories': 200.6,
      'protein': 30.4,
      'carbs': 5.5,
      'fat': 0.0,
    };
    expect(await parseResponse(responseForArguments(jsonEncode(values))), {
      'calories': 201,
      'protein': 30,
      'carbs': 6,
      'fat': 0,
    });
  });

  test('plain JSON content fallback is validated and accepted', () async {
    expect(
      await parseResponse(
        responseForMessage({'content': jsonEncode(nutrition)}),
      ),
      nutrition,
    );
  });

  test('fenced JSON content fallback accepts surrounding whitespace', () async {
    final content = '  \n```json\n${jsonEncode(nutrition)}\n```\n  ';
    expect(
      await parseResponse(responseForMessage({'content': content})),
      nutrition,
    );
  });

  test('every required nutrition field must be present', () async {
    for (final field in nutrition.keys) {
      final incomplete = Map.of(nutrition)..remove(field);
      await expectLater(
        parseResponse(responseForArguments(jsonEncode(incomplete))),
        throwsA(isA<NutritionParseException>()),
        reason: 'Missing $field must not become zero',
      );
    }
  });

  test(
    'invalid numbers and types are rejected for every nutrition field',
    () async {
      for (final field in nutrition.keys) {
        for (final invalid in [
          null,
          true,
          false,
          -1,
          -0.1,
          '200',
          '200 kcal',
          'unknown',
          [],
          {},
        ]) {
          final values = <String, dynamic>{...nutrition, field: invalid};
          await expectLater(
            parseResponse(responseForArguments(jsonEncode(values))),
            throwsA(isA<NutritionParseException>()),
            reason: '$field with value $invalid must be rejected',
          );
        }
      }
    },
  );

  test('an overflowing JSON number is rejected rather than rounded', () async {
    final arguments = jsonEncode(nutrition).replaceFirst('200', '1e999');
    await expectLater(
      parseResponse(responseForArguments(arguments)),
      throwsA(isA<NutritionParseException>()),
    );
  });

  test(
    'malformed JSON and non-object arguments do not become zero nutrition',
    () async {
      for (final arguments in [
        '',
        'not JSON',
        '{"calories":200,',
        'null',
        '[]',
        '200',
        '{}',
      ]) {
        await expectLater(
          parseResponse(responseForArguments(arguments)),
          throwsA(isA<NutritionParseException>()),
        );
      }
    },
  );

  test(
    'malformed response envelopes consistently report a parse error',
    () async {
      for (final body in [
        'not JSON',
        'null',
        '[]',
        '{}',
        jsonEncode({'choices': []}),
        jsonEncode({'choices': 'wrong type'}),
        jsonEncode({
          'choices': [null],
        }),
        jsonEncode({
          'choices': [{}],
        }),
        responseForMessage({}),
        responseForMessage({'content': null}),
        responseForMessage({'content': 123}),
        responseForMessage({'content': 'not JSON'}),
        responseForMessage({'content': '{}'}),
      ]) {
        await expectLater(
          parseResponse(body),
          throwsA(isA<NutritionParseException>()),
        );
      }
    },
  );

  test(
    'a malformed function call cannot silently use fallback content',
    () async {
      for (final functionCall in [
        'wrong type',
        {},
        {'name': 'other_function', 'arguments': jsonEncode(nutrition)},
        {'name': 'return_nutrition'},
        {'name': 'return_nutrition', 'arguments': null},
        {'name': 'return_nutrition', 'arguments': nutrition},
        {'name': 'return_nutrition', 'arguments': 'invalid JSON'},
      ]) {
        await expectLater(
          parseResponse(
            responseForMessage({
              'function_call': functionCall,
              'content': jsonEncode(nutrition),
            }),
          ),
          throwsA(isA<NutritionParseException>()),
        );
      }
    },
  );

  test(
    'a response marked as truncated is rejected even with valid JSON',
    () async {
      await expectLater(
        parseResponse(
          responseForMessage({
            'function_call': {
              'name': 'return_nutrition',
              'arguments': jsonEncode(nutrition),
            },
          }, finishReason: 'length'),
        ),
        throwsA(isA<NutritionParseException>()),
      );
    },
  );

  test(
    'HTTP failures expose a readable error without the raw response body',
    () async {
      await expectLater(
        parseResponse('raw provider details', status: 429),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains(
                  'Nutrition service request failed (429)',
                ) &&
                !error.toString().contains('raw provider details'),
          ),
        ),
      );
    },
  );

  test('missing API key fails before making an HTTP request', () async {
    dotenv.testLoad(fileInput: '');
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('', 200);
    });
    addTearDown(client.close);
    await expectLater(
      NutritionParser(client: client).parse('Chicken breast'),
      throwsA(
        predicate(
          (error) => error.toString().contains('Missing OPENAI_API_KEY'),
        ),
      ),
    );
    expect(requests, 0);
  });

  testWidgets(
    'invalid response keeps input, skips confirmation and save, then permits retry',
    (tester) async {
      var requests = 0;
      final client = MockClient((_) async {
        requests++;
        return http.Response(
          responseForArguments(
            requests == 1 ? 'invalid JSON' : jsonEncode(nutrition),
          ),
          200,
        );
      });
      addTearDown(client.close);
      final parser = NutritionParser(client: client);
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LogScreen(
            parseNutrition: parser.parse,
            saveEntry:
                ({required userId, required date, required entryData}) async {
                  saves++;
                  expect(Map.of(entryData)..remove('id'), {
                    'input': 'Chicken breast',
                    ...nutrition,
                  });
                },
            entriesWidget: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Chicken breast');
      await tester.enterText(find.byType(TextField).last, '2026-11-10');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(
        find.text('Error: Could not read nutrition data. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Entry saved ✅'), findsNothing);
      expect(saves, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Chicken breast',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '2026-11-10',
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Entry'), findsOneWidget);
      expect(saves, 0);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(saves, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('a valid zero-calorie estimate still reaches confirmation', (
    tester,
  ) async {
    const zeros = {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0};
    final client = MockClient(
      (_) async => http.Response(responseForArguments(jsonEncode(zeros)), 200),
    );
    addTearDown(client.close);
    final parser = NutritionParser(client: client);
    await tester.pumpWidget(
      MaterialApp(
        home: LogScreen(
          parseNutrition: parser.parse,
          entriesWidget: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Water');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Entry'), findsOneWidget);
    expect(find.text('Calories: 0 kcal'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
