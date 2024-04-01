// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '_finalizer.dart';
import '_hash_coder.dart';

typedef _WeakList<T extends Object> = List<WeakReference<T>>;

@visibleForTesting
typedef ItemToken = int;

/// Weak cache for objects.
///
/// Is useful when the immutable objects are duplicated across the codebase,
/// that impacts memory footprint.
///
/// [WeakCache] enables to store only one instance of each object,
/// without holding the object from being garbage collected.
///
/// When stored objects are released, their [WeakReference]s need to be removed
/// from the cache. There are two ways how this can be taken care of:
/// - Set [useFinalizers] to `true`.
/// - Call [defragment] method from time to time.
///
/// Balance between memory usage  and performance can be adjusted
/// with [useFinalizers] and [useUnmodifiableLists].
class WeakCache<T extends Object> {
  WeakCache({
    @visibleForTesting this.coder = standardHashCoder,
    @visibleForTesting FinalizerBuilder<ItemToken>? finalizerBuilder,
    this.useFinalizers = true,
    this.useUnmodifiableLists = true,
  }) {
    if (useFinalizers) {
      finalizerBuilder ??= buildStandardFinalizer<ItemToken>;
      _finalizer = finalizerBuilder(_onObjectGarbageCollected);
    } else {
      _finalizer = null;
    }
  }

  final _objects = <HashCode, _WeakList<T>>{};

  /// If `true`, the [Finalizer] is used to remove [WeakReference]s.
  ///
  /// If `false`, the [defragment] method needs to be called from time to time.
  final bool useFinalizers;

  late final FinalizerWrapper<ItemToken>? _finalizer;

  final bool useUnmodifiableLists;

  @visibleForTesting
  final HashCoder coder;

  void _onObjectGarbageCollected(ItemToken token) {
    _defragment<T>(_objects[token]);
  }

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
  static _WeakList<T> _defragment<T extends Object>(_WeakList<T> bin,
      {T? toRemove, T? toAdd}) {
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

  void _setFinalizer(T object, int code) {
    throw UnimplementedError('Finalizers are not implemented yet.');
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

  /// Removes empty instances of [WeakReference] used to store removed items.
  ///
  /// Should be called from time to time when [useFinalizers] is `false`.
  ///
  /// Calling this method immediately after [remove] will NOT result
  /// in removal of the reference, because
  /// garbage collection is not immediate.
  /// Instead, call this method after
  /// set of async operations following [remove], and/or immediately before
  /// memory heavy operations, to decrease chances of out of memory crash.
  ///
  /// Performs full scan of the cache, so should not be called too often.
  ///
  /// This method is not noticed to block UI thread.
  /// If it happened for your application, please
  /// [file an issue](https://github.com/dart-lang/leak_tracker/issues/new/choose).
  void defragment() {
    assert(
      useFinalizers == false,
      'This method is not needed when using finalizers.',
    );
    for (final entry in _objects.entries) {
      _objects[entry.key] = _defragment(entry.value);
    }
    _objects.removeWhere((key, value) => value.isEmpty);
  }
}
