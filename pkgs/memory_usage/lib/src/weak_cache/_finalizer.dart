// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

typedef ObjectGcCallback = void Function(Object token);

/// Finalizer builder to mock standard [Finalizer].
typedef FinalizerBuilder = FinalizerWrapper Function(
  ObjectGcCallback onObjectGc,
);

FinalizerWrapper buildStandardFinalizer(ObjectGcCallback onObjectGc) =>
    StandardFinalizerWrapper(onObjectGc);

abstract class FinalizerWrapper<T extends Object> {
  void attach({required Object object, required T token});
}

/// Finalizer wrapper to mock standard [Finalizer].
///
/// Is needed because the standard [Finalizer] is final and
/// thus cannot be implemented.
class StandardFinalizerWrapper<T extends Object>
    implements FinalizerWrapper<T> {
  StandardFinalizerWrapper(ObjectGcCallback onObjectGc)
      : _finalizer = Finalizer<T>(onObjectGc);

  final Finalizer<T> _finalizer;

  @override
  void attach({required Object object, required T token}) {
    _finalizer.attach(object, token);
  }
}
