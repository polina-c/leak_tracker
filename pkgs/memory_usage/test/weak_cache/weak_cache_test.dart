// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:memory_usage/src/weak_cache/_hash_coder.dart';
import 'package:memory_usage/src/weak_cache/weak_cache.dart';
import 'package:test/test.dart';

late bool _tick;
late WeakCache _cache;

class _MyClass {
  final int value;

  _MyClass(this.value);

  @override
  bool operator ==(Object other) => other is _MyClass && other.value == value;

  @override
  int get hashCode => value;
}

final _coders = <String, HashCoder>{
  'real': standardHashCoder,
  'alwaysTheSame': (object) => 1,
  'alterative': (object) => (_tick = !_tick) ? 1 : 2,
};

void main() {
  for (var coderName in _coders.keys) {
    for (var useFinalizers in [true, false]) {
      for (var useUnmodifiableLists in [true, false]) {
        for (var assertUnnecessaryRemove in [true, false]) {
          group(
              '$WeakCache with $coderName, '
              'useFinalizers: $useFinalizers'
              'useUnmodifiableLists: $useUnmodifiableLists'
              'assertUnnecessaryRemove: $assertUnnecessaryRemove', () {
            setUp(() {
              _tick = true;
              _cache = WeakCache<_MyClass>(
                coder: _coders[coderName]!,
                useFinalizers: useFinalizers,
                useUnmodifiableLists: useUnmodifiableLists,
                assertUnnecessaryRemove: assertUnnecessaryRemove,
              );
            });

            test('basic operations', () {
              final _MyClass? c11 = _MyClass(1);
              final _MyClass? c12 = _MyClass(1);
              final _MyClass? c2 = _MyClass(2);

              expect(_cache.putIfAbsent(c11!), c11);
              expect(_cache.putIfAbsent(c12!), c11);
              expect(_cache.locate(c11), c11);
              expect(_cache.locate(c12), c11);
              expect(_cache.locate(c2!), null);
              expect(_cache.putIfAbsent(c2), c2);

              if (useFinalizers) {
                expect(_cache.defragment(), 0);
              } else {
                expect(_cache.defragment(), 2);
              }
            });
          });
        }
      }
    }
  }
}
