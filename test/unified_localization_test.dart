import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siraj/core/localization/siraj_copy.dart';
import 'package:siraj/core/design/siraj_design.dart';
import 'package:siraj/features/chat/chat_page.dart';
import 'package:siraj/features/auth/login_page.dart';
import 'package:siraj/features/auth/signup_page.dart';
Widget english(Widget home)=>MaterialApp(locale:const Locale('en'),supportedLocales:const[Locale('ar'),Locale('en')],localizationsDelegates:const[SirajCopyDelegate(),GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],theme:SirajTheme.light(),home:home);
void main(){
 testWidgets('English chat has LTR and translated controls', (tester)async{
   await tester.pumpWidget(english(const ChatPage()));await tester.pumpAndSettle();
   expect(find.text('Conversation'),findsOneWidget);
   expect(Directionality.of(tester.element(find.byKey(const Key('chat-question-input')))),TextDirection.ltr);
   expect(find.text('Write your question or a follow-up'),findsOneWidget);
 });
 testWidgets('English account forms translate validation and security notices', (tester)async{
   await tester.pumpWidget(english(const SignupPage()));await tester.pumpAndSettle();
   expect(find.text('Create local account'),findsOneWidget);
   expect(find.text('Username'),findsOneWidget);
   await tester.pumpWidget(english(const LoginPage()));await tester.pumpAndSettle();
   expect(find.text('Log in'),findsWidgets);
   expect(find.text('Password recovery and a second account are not available in SIRAJ P0.'),findsOneWidget);
 });
}
