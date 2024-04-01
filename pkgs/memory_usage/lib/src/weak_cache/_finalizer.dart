// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

typedef ObjectGcCallback<T extends Object> = void Function(T token);

/// Finalizer builder to mock standard [Finalizer].
typedef FinalizerBuilder<T extends Object> = FinalizerWrapper<T> Function(
  ObjectGcCallback<T> onObjectGc,
);

FinalizerWrapper<T> buildStandardFinalizer<T extends Object>(
        ObjectGcCallback<T> onObjectGc) =>
    StandardFinalizerWrapper<T>(onObjectGc);

abstract class FinalizerWrapper<T extends Object> {
  void attach({required Object object, required T token});
}

/// Finalizer wrapper to mock [Finalizer].
///
/// Is needed because the [Finalizer] is final and
/// thus cannot be implemented.
class StandardFinalizerWrapper<T extends Object>
    implements FinalizerWrapper<T> {
  StandardFinalizerWrapper(ObjectGcCallback<T> onObjectGc)
      : _finalizer = Finalizer<T>(onObjectGc);

  final Finalizer<T> _finalizer;

  @override
  void attach({required Object object, required T token}) {
    _finalizer.attach(object, token);
  }
}
