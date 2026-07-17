import 'dart:async';

import 'package:dejapoo/app.dart';
import 'package:dejapoo/data/db/db_smoke_probe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local web verification gate; see [runDbSmokeProbe].
const bool _dbSmoke = bool.fromEnvironment('DB_SMOKE');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode && _dbSmoke) {
    unawaited(runDbSmokeProbe());
  }
  runApp(const ProviderScope(child: DejaPooApp()));
}
