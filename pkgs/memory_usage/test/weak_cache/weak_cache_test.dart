// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:memory_usage/src/weak_cache/weak_cache.dart';
import 'package:test/test.dart';

late WeakCache _cache;

class _MyClass {
  _MyClass(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is _MyClass && other.value == value;

  @override
  int get hashCode => value;
}

void main() {
  for (var useFinalizers in [true, false]) {
    for (var useUnmodifiableLists in [true, false]) {
      for (var assertUnnecessaryRemove in [true, false]) {
        group(
            '$WeakCache with '
            'useFinalizers: $useFinalizers, '
            'useUnmodifiableLists: $useUnmodifiableLists, '
            'assertUnnecessaryRemove: $assertUnnecessaryRemove,', () {
          setUp(() {
            _cache = WeakCache<_MyClass>(
              useFinalizers: useFinalizers,
              useUnmodifiableLists: useUnmodifiableLists,
              assertOnRemove: assertUnnecessaryRemove,
            );
          });

          test('basic operations', () {
            _MyClass? c11 = _MyClass(1);
            final c12 = _MyClass(1);
            _MyClass? c2 = _MyClass(2);

            expect(_cache.locate(c11), null);
            expect(_cache.putIfAbsent(c11), c11);
            expect(_cache.putIfAbsent(c12), c11);
            expect(_cache.locate(c11), c11);
            expect(_cache.locate(c12), c11);
            expect(_cache.locate(c2), null);
            expect(_cache.putIfAbsent(c2), c2);
            expect(_cache.locate(c2), c2);

            if (useFinalizers) {
              expect(_cache.defragment, throwsA(isA<AssertionError>()));
            } else {
              final d = _cache.defragment();
              expect(d.remaining, 2);
              expect(d.removed, 0);
            }

            c11 = null;
            c2 = null;
          });
        });
      }
    }
  }
}
