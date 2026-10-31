import '../features/library/library_contracts.dart';
import 'app_session_controller.dart';
import '../features/quiz/quiz_curriculum.dart';
import 'resource_preparation_binding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_preferences.dart';
import '../core/localization/siraj_copy.dart';
import '../core/design/siraj_design.dart';

import 'app_bootstrap.dart';
import 'app_routes.dart';
import '../integrations/ai/tutor_port.dart';
import '../integrations/ai/quiz_port.dart';

class SirajApp extends StatefulWidget {
  const SirajApp({
    super.key,
    this.debugPreview = false,
    this.preferences,
    this.resourcePreparation,
    this.sessionController,
    this.curriculum = const UnavailableQuizCurriculum(),
    this.library = const LibraryIntegration(),
    this.tutor = const UnavailableTutorPort(),
    this.sources = const UnavailableSourceResolver(),
    this.quiz = const UnavailableQuizPort(),
    this.numericPrecision = const UnavailableNumericPrecision(),
  });

  /// Only explicitly used in debug widget tests; never in release/profile.
  final bool debugPreview;
  final AppPreferencesController? preferences;
  final ResourcePreparationBinding? resourcePreparation;
  final AppSessionController? sessionController;
  final QuizCurriculumPort curriculum;
  final LibraryIntegration library;
  final TutorPort tutor;
  final SourceResolverPort sources;
  final QuizPort quiz;
  final NumericPrecisionPort numericPrecision;

  @override
  State<SirajApp> createState() => _SirajAppState();
}

class _SirajAppState extends State<SirajApp> {
  late final AppPreferencesController _preferences =
      widget.preferences ??
      AppPreferencesController(
        widget.debugPreview && kDebugMode
            ? _PreviewAppearanceStore()
            : const AndroidAppPreferencesStore(),
      );
  @override
  void dispose() {
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPreferencesScope(
    controller: _preferences,
    child: AnimatedBuilder(
      animation: _preferences,
      builder: (context, _) => MaterialApp(
        title: 'SIRAJ',
        debugShowCheckedModeBanner: false,
        theme: SirajTheme.light(),
        darkTheme: SirajTheme.dark(),
        themeMode: _preferences.value.themeMode,
        locale: _preferences.value.locale,
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          SirajCopyDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AppBootstrap(
          sessionController: widget.sessionController,
          resourcePreparation: widget.resourcePreparation,
          curriculum: widget.curriculum,
          library: widget.library,
          debugPreview: widget.debugPreview && kDebugMode,
          tutor: widget.tutor,
          sources: widget.sources,
          quiz: widget.quiz,
          numericPrecision: widget.numericPrecision,
        ),
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    ),
  );
}

// Ephemeral appearance only in the explicitly selected debug preview. Normal
// main.dart always uses app-private persistent storage and guarded bootstrap.
class _PreviewAppearanceStore implements AppPreferencesStore {
  AppPreferences _value = const AppPreferences();
  @override
  Future<AppPreferences> read() async => _value;
  @override
  Future<void> write(AppPreferences next) async {
    _value = next;
  }
}
