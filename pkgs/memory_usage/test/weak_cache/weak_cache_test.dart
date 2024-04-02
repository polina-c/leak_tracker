// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:memory_usage/src/weak_cache/_hash_coder.dart';
import 'package:memory_usage/src/weak_cache/weak_cache.dart';
import 'package:test/test.dart';

late bool _tick;
late WeakCache _cache;

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
              _cache = WeakCache(
                coder: _coders[coderName]!,
                useFinalizers: useFinalizers,
                useUnmodifiableLists: useUnmodifiableLists,
                assertUnnecessaryRemove: assertUnnecessaryRemove,
              );
            });

            test('basic operations', () {});
          });
        }
      }
    }
  }
}
