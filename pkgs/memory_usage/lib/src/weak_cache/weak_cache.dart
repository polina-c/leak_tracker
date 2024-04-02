// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '_finalizer.dart';
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
    @visibleForTesting FinalizerBuilder<HashCode>? finalizerBuilder,
    this.useFinalizers = true,
    this.useUnmodifiableLists = true,
    this.assertUnnecessaryRemove = true,
  }) {
    if (useFinalizers) {
      finalizerBuilder ??= buildStandardFinalizer<HashCode>;
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

  final bool assertUnnecessaryRemove;

  late final FinalizerWrapper<HashCode>? _finalizer;

  /// Weather to optimize internal lists fr memory footprint.
  ///
  /// If `true`, the internal lists are optimized for memory footprint:
  /// they are converted to unmodifiable before being stored.
  ///
  /// If `false`, the lists are optimized for performance.
  final bool useUnmodifiableLists;

  @visibleForTesting
  final HashCoder coder;

  void _onObjectGarbageCollected(HashCode token) {
    _defragment(token);
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
  /// It is not necessary to call this method when [useFinalizers] is `true`.
  void remove(T object) {
    assert(() {
      assert(
        !useFinalizers || !assertUnnecessaryRemove,
        'This method is not needed when using finalizers.',
      );
      return true;
    }());

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
    _defragment(code, toRemove: object);
  }

  /// Defragments references at [code].
  ///
  /// If [toRemove] and/or [toAdd] are provided, removes and/or adds
  /// the objects.
  ///
  /// If [removeEmpty] is `true`, removes the bin if it is empty.
  /// This flag is needed to avoid exception of concurrent modification during
  /// iteration.
  ({int removed, int remaining}) _defragment(
    HashCode code, {
    T? toRemove,
    T? toAdd,
    bool removeEmpty = true,
  }) {
    var bin = _objects[code];
    if (bin == null && toAdd == null) return (removed: 0, remaining: 0);
    bin ??= [];

    var newBin = <WeakReference<T>>[];

    for (var i = 0; i < bin.length; i++) {
      final target = bin[i].target;
      assert(target != toAdd);
      if (target != toRemove && target != null) {
        newBin.add(bin[i]);
      }
    }
    if (toAdd != null) newBin.add(WeakReference(toAdd));
    if (newBin.isEmpty && removeEmpty) {
      _objects.remove(code);
      return (removed: bin.length, remaining: 0);
    }
    if (toRemove == null && toAdd == null && newBin.length == bin.length) {
      return (removed: 0, remaining: newBin.length);
    }

    if (useUnmodifiableLists) {
      newBin = List.unmodifiable(newBin);
    }

    _objects[code] = newBin;

    return (removed: bin.length - newBin.length, remaining: newBin.length);
  }

  void _maybeSetFinalizer(T object, int code) {
    if (!useFinalizers) return;
    _finalizer?.attach(object: object, token: code);
  }

  /// Adds [object] to the cache if it is not there.
  ///
  /// If and object equal [object] to is already in the cache,
  /// that object from cache.
  /// Otherwise adds [object] to the cache and returns it.
  T putIfAbsent(T object) {
    final code = coder(object);
    final bin = _objects[code];

    if (bin == null) {
      _objects[code] = List.unmodifiable([WeakReference(object)]);
      return object;
    }

    assert(bin.isNotEmpty);
    final existing = bin.firstWhereOrNull((r) => r.target == object);
    if (existing != null) return existing.target!;

    _defragment(code, toAdd: object);
    _maybeSetFinalizer(object, code);
    return object;
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
  ///
  /// Returns number of remaining instances.
  ({int removed, int remaining}) defragment() {
    assert(
      useFinalizers == false,
      'This method is not needed when using finalizers.',
    );
    var removed = 0;
    var remaining = 0;
    for (final code in _objects.keys) {
      final result = _defragment(code, removeEmpty: true);
      removed += result.removed;
      remaining += result.remaining;
    }
    _objects.removeWhere((key, value) => value.isEmpty);
    return (removed: removed, remaining: remaining);
  }
}
