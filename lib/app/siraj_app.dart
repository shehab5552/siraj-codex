import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/design/siraj_design.dart';

import 'app_bootstrap.dart';
import 'app_routes.dart';
import '../integrations/ai/tutor_port.dart';
import '../integrations/ai/quiz_port.dart';

class SirajApp extends StatelessWidget {
  const SirajApp({
    super.key,
    this.debugPreview = false,
    this.tutor = const UnavailableTutorPort(),
    this.sources = const UnavailableSourceResolver(),
    this.quiz = const UnavailableQuizPort(),
    this.numericPrecision = const UnavailableNumericPrecision(),
  });

  /// Only explicitly used in debug widget tests; never in release/profile.
  final bool debugPreview;
  final TutorPort tutor;
  final SourceResolverPort sources;
  final QuizPort quiz;
  final NumericPrecisionPort numericPrecision;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سراج',
      debugShowCheckedModeBanner: false,
      theme: SirajTheme.light(),
      darkTheme: SirajTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: AppBootstrap(
        debugPreview: debugPreview && kDebugMode,
        tutor: tutor,
        sources: sources,
        quiz: quiz,
        numericPrecision: numericPrecision,
      ),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
