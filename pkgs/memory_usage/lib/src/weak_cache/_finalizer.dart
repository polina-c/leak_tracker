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

abstract class FinalizerWrapper {
  void attach(Object object, Object token);
}

/// Finalizer wrapper to mock standard [Finalizer].
///
/// Needed because the standard [Finalizer] is final and
/// thus cannot be implemented.
class StandardFinalizerWrapper implements FinalizerWrapper {
  StandardFinalizerWrapper(ObjectGcCallback onObjectGc)
      : _finalizer = Finalizer<Object>(onObjectGc);

  final Finalizer<Object> _finalizer;

  @override
  void attach(Object object, Object token) {
    _finalizer.attach(object, token);
  }
}
