// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '_hash_coder.dart';

typedef _WeakList<T extends Object> = List<WeakReference<T>>;

/// Weak cache for objects.
///
/// Is useful when the immutable objects are duplicated across the codebase,
/// that impacts memory footprint.
///
/// [WeakCache] enables to store only one instance of each object,
/// without holding the object from being garbage collected.
///
/// When stored objects are released [WeakReference]s need to be removed.
/// There are two ways how [WeakCache] this can be taken care of:
/// - Set [useFinalizers] to `true`.
/// - Call [defragment] method from time to time.
///
/// Balance between performance and memory usage can be adjusted
/// with [useFinalizers] and [useUnmodifiableLists].
class WeakCache<T extends Object> {
  WeakCache({
    @visibleForTesting this.coder = standardHashCoder,
    this.useFinalizers = true,
    this.useUnmodifiableLists = true,
  }) {
    if (useFinalizers) {
      throw UnimplementedError('Finalizers are not implemented yet.');
    }
  }

  final _objects = <HashCode, _WeakList<T>>{};

  final bool useFinalizers;

  final bool useUnmodifiableLists;

  @visibleForTesting
  final HashCoder coder;

  /// Returns object equal to [object] if it is in the cache.
  ///
  /// Method `contains` is not implemented intentionally,
  /// because weakness of the storage would make its result not persisting.
  T? locate(T object) {
    final code = coder(object);
    final bin = _objects[code];
    if (bin == null) return null;
    final ref = bin.firstWhereOrNull((r) => r.target == object);
    return ref?.target;
  }

  /// Removes object equal to [object] if it is in the cache.
  ///
  /// Also defragments the bin with hash [Object.hashCode] of [object].
  void remove(T object) {
    final code = coder(object);
    final bin = _objects[code];
    if (bin == null) return;

    assert(bin.isNotEmpty);
    if (bin.length == 1) {
      final target = bin[0].target;
      if (target == object || target == null) {
        _objects.remove(code);
      }
      return;
    }

    // Rare case when hash codes of different objects are equal.
    assert(bin.length > 1);
    final defragmented = _defragment(bin, toRemove: object);
    if (defragmented.isEmpty) {
      _objects.remove(code);
    } else {
      _objects[code] = defragmented;
    }
  }

  /// Returns list without empty references.
  ///
  /// If [toRemove] and/or [toAdd] are provided, removes and/or adds
  /// the objects.
  ///
  /// Returns [bin] if set of objects did not change.
  _WeakList<T> _defragment(_WeakList<T> bin, {T? toRemove, T? toAdd}) {
    final result = <WeakReference<T>>[];
    for (var i = 0; i < bin.length; i++) {
      final target = bin[i].target;
      assert(target != toAdd);
      if (target != toRemove && target != null) {
        result.add(bin[i]);
      }
    }
    if (toAdd != null) result.add(WeakReference(toAdd));
    if (toRemove == null && toAdd == null && result.length == bin.length) {
      return bin;
    }
    return result;
  }

  ({T object, bool wasAbsent}) putIfAbsent(T object) {
    final code = coder(object);
    final bin = _objects[code];

    if (bin == null) {
      _objects[code] = [WeakReference(object)]; //unmodifiable ????
      return (object: object, wasAbsent: true);
    }

    assert(bin.isNotEmpty);
    final existing = bin.firstWhereOrNull((r) => r.target == object);
    if (existing != null) return (object: existing.target!, wasAbsent: false);

    final defragmented = _defragment(bin, toAdd: object);
    assert(defragmented != bin);
    _objects[code] = defragmented;
    return (object: object, wasAbsent: true);
  }

  void defragment() {
    for (final entry in _objects.entries) {
      _objects[entry.key] = _defragment(entry.value);
    }
    _objects.removeWhere((key, value) => value.isEmpty);
  }
}
