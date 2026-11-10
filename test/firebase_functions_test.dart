import 'package:caltrac/services/firebase_functions.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCallable extends Fake implements HttpsCallable {
  FakeCallable(this.result);
  final Future<HttpsCallableResult<dynamic>> result;
  dynamic parameters;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    this.parameters = parameters;
    return await result as HttpsCallableResult<T>;
  }
}

class FakeFunctions extends Fake implements FirebaseFunctions {
  FakeFunctions(this.callable);
  final HttpsCallable callable;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    expect(name, 'addEntryLog');
    return callable;
  }
}

class FakeResult extends Fake implements HttpsCallableResult<dynamic> {}

void main() {
  test(
    'food save passes the payload and completes after callable success',
    () async {
      final callable = FakeCallable(Future.value(FakeResult()));
      final entry = {
        'input': 'Chicken breast',
        'calories': 200,
        'id': 'test-entry-id',
      };
      await logEntryToFirebase(
        userId: 'test-user',
        date: DateTime(2026, 1, 2),
        entryData: entry,
        functions: FakeFunctions(callable),
      );
      expect(callable.parameters, {
        'userId': 'test-user',
        'dateString': '2026-01-02',
        'entryData': entry,
      });
    },
  );

  test('food save propagates the original Firebase failure', () async {
    final error = FirebaseFunctionsException(
      code: 'unavailable',
      message: 'Try again',
    );
    final callable = FakeCallable(Future.error(error));
    await expectLater(
      logEntryToFirebase(
        userId: 'test-user',
        date: DateTime(2026, 1, 2),
        entryData: {'input': 'Chicken breast'},
        functions: FakeFunctions(callable),
      ),
      throwsA(same(error)),
    );
  });
}
