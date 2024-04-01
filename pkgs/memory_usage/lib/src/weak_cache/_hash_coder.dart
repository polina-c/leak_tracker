// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Result of [Object.hashCode].
typedef HashCode = int;

/// Builder to mock standard [Object.hashCode].
typedef HashCoder = HashCode Function(Object object);

int standardHashCoder(Object object) => object.hashCode;
