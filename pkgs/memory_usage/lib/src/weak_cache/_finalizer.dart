// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

typedef ObjectGcCallback = void Function(Object token);

/// Finalizer builder to mock standard [Finalizer].
typedef FinalizerBuilder = Finalizer Function(ObjectGcCallback onObjectGc);

Finalizer buildFinalizer(ObjectGcCallback onObjectGc) =>
    Finalizer<Object>(onObjectGc);
