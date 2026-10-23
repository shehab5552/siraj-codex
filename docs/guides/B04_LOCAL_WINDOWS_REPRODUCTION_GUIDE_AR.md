# B-04 — دليل نقل الإصلاحات وتجربتها على Windows وSamsung

التاريخ: 23 أكتوبر 2026 بتوقيت عدن. المشروع المحلي الذي ستنفذ عليه **أنت**
الخطوات: `D:\SIRAJ\App Flutter`. لم يصل Codex إليه أو إلى `siraj-p0`، ولم
يفحص مطابقته؛ الأوامر التالية تعليمات مستقبلية وليست سجل تنفيذ على جهازك.

الهاتف المقترح: Samsung SM-N986U / Android 13. يجب تسجيل RAM/ABI الفعليين؛
اسم الجهاز وحده لا يثبت أنه يطابق هدف P0 ذي 6GB.

## 1. ما الذي نعرفه قبل النقل؟

- الإصلاح المرجعي في [PR #5](https://github.com/shehab5552/siraj-codex/pull/5)،
  الفرع `codex/b04-security-repair-01`، الرأس
  `17ac3cd1d27acd0ae32a24cc09a5aa99b363c126`.
- قاعدة المقارنة **قبل الإصلاح**:
  `651af0d62d05761c80d9a8cbc9d1f51b836929eb`.
- Commit الكود **بعد الإصلاح**:
  `80b4f0fe1a228731ff6ae57ccdeb5598d201f681`. Commit الرأس التالي توثيق فقط.
- PBKDF2 وSalt وAES-GCM وKeystore كانت موجودة. ما أصلح هو العزل والتزامن
  والإلغاء والتعافي وحدود التخزين، وليس تغيير خوارزمية P0.
- لا دليل من Linux على أن تعليق مشروعك الأصلي له السبب نفسه. لا نستطيع
  مقارنة تلك التجربة بكودها/Logcat/الجهاز لأننا لم نصل إليها.
- `600000` مرشح مبرر بمرجع OWASP؛ لا production default معتمد ولا فتح بوابة
  AppBootstrap. الاختبار المعزول يمرر هذا المرشح صراحة.

نتائج السحابة وخطوات Android الفعلية، بما فيها نتيجة Actions عند اكتمالها،
في [تقرير التحقق](../reports/B-04_ANDROID_VERIFICATION_AND_TRANSFER_AR.md).
لا تعامل خانات NOT_RUN/PENDING كأنها PASS.

## 2. حفظ النسخة المحلية قبل أي تعديل

افتح PowerShell في VS Code. الأمثلة متوافقة مع Windows PowerShell 5.1؛
لا تعتمد `&&` أو `$PSNativeCommandUseErrorActionPreference`.

```powershell
$ErrorActionPreference = 'Stop'
$project = 'D:\SIRAJ\App Flutter'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = "D:\SIRAJ\B04-backup-$stamp"
Set-Location -LiteralPath $project
git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'المجلد ليس مستودع Git؛ احفظ نسخة كاملة وهيئ إدارة النسخ أولًا.' }
git status --short
git branch --show-current
git log -1 --oneline
New-Item -ItemType Directory -Path $backupRoot | Out-Null
robocopy $project "$backupRoot\working-copy" /E /COPY:DAT /R:1 /W:1 /XJ /XD .git .dart_tool build .gradle
if ($LASTEXITCODE -ge 8) { throw 'فشل النسخ الاحتياطي؛ لا تتابع.' }
git bundle create "$backupRoot\history.bundle" --all
if ($LASTEXITCODE -ne 0) { throw 'فشل حفظ سجل Git؛ لا تتابع.' }
git diff --binary --output="$backupRoot\unstaged.patch"
git diff --cached --binary --output="$backupRoot\staged.patch"
git switch -c "local/b04-android-$stamp"
if ($LASTEXITCODE -ne 0) { throw 'لم يُنشأ الفرع؛ لا تتابع.' }
git status --short
```

وجهة النسخ خارج المشروع، و`/E` لا يحذف ملفات الوجهة؛ لا تستخدم `/MIR`.
نسخة الملفات تشمل التعديلات غير الملتزمة والملفات غير المتتبعة، وbundle
يحفظ Commits. لا ترفع النسخة الاحتياطية أو `.env` أو `local.properties`
أو أي مفاتيح إلى GitHub. لا تستخدم `git clean`/`reset --hard`/حذف DB.

إن ظهر عمل سابق في `git status`، راجعه واحفظه في Commit انتقائي على هذا
الفرع قبل خلطه بإصلاح B-04. لا تشغّل `git add .` دون مراجعة الأسرار. إن لم
يمكنك فصل العمل، اختبر في نسخة العمل الاحتياطية الجديدة بدل استبدال ملفات
متغيرة لا تعرف مصدرها. نجاح backup ليس إذنًا بإتلاف بيانات الهاتف.

## 3. الحصول على المرجع دون دمج المستودعين

نزّل مرجع Codex في مجلد **مجاور مستقل**، وليس داخل المشروع الأصلي:

```powershell
$reference = 'D:\SIRAJ\CodexB04Reference'
if (Test-Path -LiteralPath $reference) { throw 'اختر مجلد مرجع جديدًا فارغًا أو تحقق من نسخته أولًا.' }
git clone --branch codex/b04-android-verification-guide https://github.com/shehab5552/siraj-codex.git $reference
if ($LASTEXITCODE -ne 0) { throw 'تعذر تنزيل المرجع.' }
git -C $reference rev-parse HEAD
$manifestPath = Join-Path $reference 'docs\qa\b04_reference\manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.base
$manifest.code_commit
```

لا تضف المستودع الأصلي كـremote إلى Codex ولا تنفذ Merge/Cherry-pick لـPR #5
كله في مشروعك. سيختلف مخططك أو أسماء APIs أو package؛ النقل يدوي حسب العقود.
المرجع يحتوي 32 Patch فعلية مع SHA-256 قبل/بعد، والكود الكامل للملفات
الجديدة تحت `docs/qa/b04_reference/new_files/` بامتداد `.txt` إضافي كي لا
يحللها Flutter كنسخة تطبيق ثانية. إزالة `.txt` تكون عند إضافة ملف متوافق فقط.

تحقق من عدم تلف الـPatches قبل فتحها:

```powershell
$bundle = Join-Path $reference 'docs\qa\b04_reference'
foreach ($entry in $manifest.entries) {
    $patchFile = Join-Path $bundle $entry.patch
    $actual = (Get-FileHash -LiteralPath $patchFile -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $entry.patch_sha256) { throw "Patch تالف: $($entry.path)" }
}
```

مقارنة ملفك مع الملف المرجعي، مثال:

```powershell
code --diff "$project\lib\features\auth\password_hasher.dart" "$reference\lib\features\auth\password_hasher.dart"
code "$bundle\patches\lib\features\auth\password_hasher.dart.patch"
```

إن كان اسم package في `pubspec.yaml` غير `siraj`، عدّل imports في **الملفات
المنقولة فقط** لتشير إلى package المحلي. لا تستبدل أسماء المشروع كاملة.
راجع SDK والواجهات الموضحة أدناه؛ لا تنسخ AuthService أو Repository كاملًا
لمجرد أن الملف يحمل الاسم نفسه.

## 4. خريطة كل تعديل والكود الدقيق المقابل له

لكل مسار في الجداول Patch كاملة في
`docs/qa/b04_reference/patches/<المسار>.patch`، مثبتة بين SHA القاعدة وCommit
الكود أعلاه. Patch تشمل imports والتواقيع والسياق، وليس شرحًا بديلًا للكود.
مصدر الملف الجديد كاملًا: `new_files/<المسار>.txt`.

| المسار النسبي | الوظيفة والتغيير والسبب | طريقة النقل | التبعيات/Android |
|---|---|---|---|
| `lib/features/auth/kdf_worker.dart` | Isolate محدود؛ cancel/busy/deadline؛ DartPbkdf2 | ملف جديد كامل إن لم توجد خدمة مكافئة؛ لا تكرر Worker موجودًا | Dart/cryptography 2.9 API؛ لا Kotlin/Gradle |
| `lib/features/auth/password_hasher.dart` | تفويض الاشتقاق للعامل، حدود UTF-8/metadata ومعلمات محفوظة | نقل تغييرات constructor/hashPassword/verifyPassword؛ احتفظ بعقد بياناتك | kdf_worker؛ Salt16 وhash256؛ بلا dependency جديدة في Codex |
| `lib/features/auth/auth_operation_lane.dart` | ترتيب Auth على DB واحدة وإلغاء/تصريف الطلب القديم | ملف جديد كامل عند تطابق AuthFailure وDB owner | kdf_worker/auth_models؛ لا Android |
| `lib/features/auth/auth_models.dart` | typed errors و`accountCreated` اختياري | نقل enum/حقل الفشل؛ أبقِ AuthSession/Marker المحليين بعد مطابقة الحقول | JSON contract؛ لا schema migration |
| `lib/features/auth/auth_service.dart` | Lane، Marker ثم CAS، حد COMMIT، retry إبطال | **نقل دوال وحقول مترابطة، لا استبدال أعمى** | UserRepository/SessionGuard/Marker/Hasher/Lane |
| `lib/data/user_repository.dart` | فحص الإلغاء داخل create/CAS، مطابقة nonce عند الإبطال والحذف | نقل SQL والمعاملات بعد مطابقة أعمدة/أنواع المخطط | حساب/epoch/nonce BLOB وDrift؛ لا نسخ schema من Codex |
| `lib/features/auth/session_guard.dart` | حجب محلي مشترك وبصمة هوية؛ سلطة Retry منفصلة | نقل block/isBlocked/مطابقة الإبطال مع واجهتك | SHA256، DB owner؛ لا صلاحية بيانات عبر مسار Retry |
| `lib/features/auth/session_marker_store.dart` | عقد قناة ثابت ومهلة15s وحد4096 | نقل adapter فقط إذا قررت استخدام القناة المباشرة | MethodChannel/Kotlin؛ لا تخزين plaintext بديل |
| `lib/features/auth/startup_session_resolver.dart` | تنظيف Marker قديمة داخل نفس Lane، فشل مغلق | نقل resolve/read/cleanup مع الحفاظ على حالات startup | نفس DB وMarker وGuard |
| `lib/features/auth/signup_page.dart` | onCancel وaccountCreated→Login ومسح حقول | نقل callbacks والحالة فقط مع الحفاظ على تصميمك | AuthFailure/LoginPage؛ لا اختيار iterations في Widget |
| `lib/features/auth/login_page.dart` | إلغاء الطلب ومسح كلمة المرور | نقل callback/dispose/success مع handler الموجود | AuthService callback؛ لا KDF داخل Widget |
| `lib/data/conversation_repository.dart` | nonce وفحص صلاحية الطلب داخل معاملة أول USER | نقل الحراسة مع الاحتفاظ بـB-08/history/idempotency إن كانت موجودة | مخططك وSessionGuard؛ يتعارض نصيًا مع PR #4 |
| `lib/features/chat/conversation_draft_controller.dart` | تمرير nonce وفحص الحجب إلى الحفظ | دمج معاملات الاستدعاء؛ أبقِ منطق B-08 الموجود | Hasher/SessionGuard/ConversationRepository؛ يتعارض مع PR #4 |
| `android/app/src/main/kotlin/com/example/siraj/SirajSecureSessionChannel.kt` | عامل native مشترك محدود، disposed fence، strict UTF-8 وحدود | Patch إذا القناة موجودة؛ نقل class كامل فقط بعد مقارنة القناة/namespace | AndroidKeyStore/JCA APIs؛ لا secure-storage plugin جديد |
| `android/app/src/main/kotlin/com/example/siraj/MainActivity.kt` | dispose للقناة القديمة قبل استبدالها | **نقل السطر المعني فقط**؛ حافظ على قنوات LLM/PDF وأي hooks أخرى | namespace المحلي والقناة أعلاه |
| `android/app/src/main/AndroidManifest.xml` | allowBackup=false وربط قواعد النسخ | دمج attributes فقط، لا استبدال Manifest | ملفات XML التالية؛ تحقق compileSdk داعم dataExtractionRules |
| `android/app/src/main/res/xml/backup_rules.xml` | استثناء بيانات التطبيق من backup | XML جديد كامل إذا لا سياسة قائمة؛ وإلا ادمج السياسة | Manifest؛ لا تحذف بيانات الجهاز |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | استثناء cloud-backup وdevice-transfer | XML جديد كامل أو دمج بعد مراجعة الموجود | Android31+ schema/compileSdk؛ يظل OEM اختبارًا فعليًا |

ملفات التحقق المرجعية، جميعها ضمن الـ32 Patch:

| المسار | ما ينقل وكيف يختبر | الاعتمادية |
|---|---|---|
| `integration_test/b04_android_secure_session_test.dart` | Patch لاستخدام600000 وإضافة كلمة خاطئة؛ كامل الاختبار في checkout المرجعي | Auth/Drift/القناة الحقيقية؛ imports package المحلية |
| `test/b04_kdf_worker_test.dart` | ملف جديد كامل عند مطابقة API | worker، fixture؛ vectors/cancel/deadline/busy |
| `test/fixtures/b04_pbkdf2_sha256_vectors.json` | بيانات عامة اصطناعية؛ نقل كامل | Python/OpenSSL مرجع مستقل، لا أسرار مستخدم |
| `test/b04_auth_race_test.dart` | ملف جديد بعد تكييف Repository | Auth/SQLite؛ السباقات وحد COMMIT |
| `test/b04_security_recovery_test.dart` | ملف جديد بعد تكييف عقود الفشل | دعم Marker/Repository الاختباري |
| `test/b04_cross_store_recovery_test.dart` | ملف جديد | Lane وStartup؛ ACK/تنظيف Marker |
| `test/b04_full_flow_test.dart` | ملف جديد؛ ملف SQLite مؤقت فقط | Auth/Drift؛ Delete والموارد |
| `test/b04_auth_real_widget_test.dart` | ملف جديد؛ صفحاتك إن تغيرت مفاتيحها تحتاج تكييفًا | Auth حقيقي600000 وMarker اختبار فقط |
| `test/b04_keystore_channel_test.dart` | ملف جديد؛ mock channel في الاختبار فقط | services/test؛ ليس Keystore native |
| `test/b04_late_message_test.dart` | ملف جديد بعد مطابقة عقود الحفظ | DB/controller/SessionGuard |
| `test/b04_backup_policy_test.dart` | ملف جديد مع تكييف اسم package/مساراتك إذا لزم | ملفات Manifest/XML؛ ليس OEM acceptance |
| `test/support/auth_test_marker.dart` | دعم اختبار جديد؛ لا يدخل production | SessionMarkerStore؛ faults محقونة |
| `test/support/auth_test_repository.dart` | دعم اختبار جديد؛ لا يدخل production | UserRepository؛ faults/concurrency |
| `tool/b04_kdf_benchmark.dart` | أداة synthetic كاملة عند توافق Hasher | تقيس Dart host فقط؛ ليست قياس الهاتف عند `dart run` على Windows |

أدوات هذه المتابعة ليست إصلاحات إنتاجية إضافية:

| المسار | الاستخدام |
|---|---|
| `integration_test/support/b04_probe_app.dart` | entry point Debug Android فقط؛ DB `siraj_b04_probe`، نطاق Keystore `b04_test`، Signup/Login الحقيقيان، Logout/Delete ومورد سجل MISSING |
| `integration_test/b04_android_kdf_metrics_test.dart` | ثلاث عينات600000 وقياس heartbeat/RSS والإلغاء **على Android**؛ لا يطبع كلمة/Hash/nonce |
| `integration_test/b04_android_probe_ui_test.dart` | قيادة UI مع Auth/Keystore/SQLite حقيقية؛ إنشاء USER محفوظة وDelete cascade وبقاء المورد؛ التحميل ليس وحده إثبات عدم ANR |
| `test/b04_probe_app_test.dart` | 3 اختبارات UI للمسبار باستخدام SQLite/Auth الحقيقيين وMarker معزول،1000 لتدفق UI فقط |
| `.github/workflows/b04-android-verification.yml` | GitHub-hosted API33 Emulator؛ تثبيت package اختبار منفصل، لا يدمج PR ولا يفتح Gate |
| `tool/export_b04_reference.py` | إعادة توليد المرجع من Commits Codex المحددة؛ لا ينقل الإصلاحات إلى مشروعك تلقائيًا |

## 5. شرح PBKDF2: قبل وبعد وعلاقة الملفات

المقتطف السابق الحقيقي من `PasswordHasher._derive` في قاعدة Codex:

```dart
final pbkdf2 = Pbkdf2.hmacSha256(iterations: iterations, bits: hashBits);
final secretKey = await pbkdf2.deriveKeyFromPassword(
  password: password,
  nonce: salt,
);
try {
  final bytes = await secretKey.extractBytes();
  return Uint8List.fromList(bytes);
} finally {
  secretKey.destroy();
}
```

كان الاستدعاء في isolate المستدعي وباختيار provider للمكتبة، دون عامل مملوك
قابل للإيقاف أو حد busy/deadline. `async/await` وحده لا يضمن نقل CPU عن UI؛
بالمقابل، لا يثبت هذا أن النسخة السابقة كانت deadlocked: قياس Linux اكتمل
2506ms مع247 heartbeat ticks. لا نعرف كود تجربتك السابقة على Android أو
provider/الإصدار/الجهاز، ولا ننسب لها هذا السبب قطعًا.

المقتطف المعدل داخل `PasswordHasher`:

```dart
final hash = await _worker.derive(
  password: password,
  salt: salt,
  iterations: iterations,
  cancellation: cancellation,
);
```

وفي worker الفعلي، داخل isolate جديد:

```dart
key = await DartPbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: input.iterations,
  bits: 256,
  pauseFrequency: 0,
).deriveKey(secretKey: password, nonce: input.salt);
final derived = Uint8List.fromList(await key.extractBytes());
input.reply.send(derived);
derived.fillRange(0, derived.length, 0);
```

`pauseFrequency: 0` جائز هنا لأن هذا CPU worker منفصل؛ **لا تنقل هذا الخيار
إلى KDF على UI isolate**. يرسل العامل bytes إلى ReceivePort، ويستقبل parent
النتيجة/الخطأ أو إشارة الإلغاء. Parent يطبق `Future.any(...).timeout(60s)`،
وفي `finally` يقتل isolate ويغلق port/subscription ويمسح buffer المملوك.
يوجد `_busy` يمنع عاملين متداخلين في worker نفسه. Lane فوقه يمنع تداخل
credential operations على DB المشتركة. الإلغاء لا يحول نفسه إلى نجاح.

مسار الاستدعاء:

```text
SignupPage/LoginPage callback
  -> AuthService.createAccount/login
     -> AuthOperationLane.run + cancellation/generation
        -> PasswordHasher.hashPassword/verifyPassword
           -> IsolatePbkdf2.derive -> DartPbkdf2 في isolate CPU
        -> Marker.write acknowledged
        -> UserRepository.compareAndSetNonceHash داخل SQLite transaction
        -> COMMIT الناجح ثم نشر AuthSession في RAM
```

Salt16bytes جديد من Random.secure، hash256bits، تحقق بالمعلمات المحفوظة
ومقارنة ثابتة العمل. لا truncate لكلمة المرور؛ الحد1024 UTF-8bytes موثق
في API. لا تخزن كلمة المرور الأصلية. نسخ البايتات قبل destroy مهم حتى لا
ترجع buffer مسحتها المكتبة. مسح buffers لا يعني ضمان محو managed Strings.

600000 هو مرشح PBKDF2-HMAC-SHA256 وفق
[OWASP Password Storage](https://github.com/OWASP/CheatSheetSeries/blob/master/cheatsheets/Password_Storage_Cheat_Sheet.md)،
وليس قيمة منخفضة لتسريع الاختبار. يتطلب DD-05 قياس جهاز P0 ومراجعة أمنية.
عينات Linux بعد الإصلاح1900/1894/1918ms ليست ضمانًا لوقت Samsung. العامل
يتيح استمرار event loop وإلغاء CPU؛ وحده لا يثبت غياب ANR أو ضغط الذاكرة
على Android. متجهات Python/OpenSSL السبعة تثبت صحة الخوارزمية للمدخلات المختبرة.

## 6. شرح Keystore وSQLite: ما الذي تغير فعلًا؟

القناة المباشرة Kotlin/MethodChannel **كانت موجودة**. لم يُستبدل AES-256-GCM
ولم يُدخل flutter_secure_storage من جديد. `KeyGenerator` مع provider
`AndroidKeyStore` ينشئ AES256/GCM/NoPadding بمفتاح لا يعاد إلى Dart، وIV
عشوائي12bytes وtag128. ciphertext فقط في app-private SharedPreferences؛
SQLite يحفظ SHA256 للـsession nonce، وليس nonce أو كلمة المرور plaintext.

قبل الإصلاح كان لكل Channel عامل:

```kotlin
private val worker = Executors.newSingleThreadExecutor { task ->
    Thread(task, "siraj-secure-session").apply { isDaemon = true }
}
// dispose:
channel.setMethodCallHandler(null)
worker.shutdown()
```

`shutdown()` لا يلغي ما صُفّ من قبل؛ Engine جديدة قد تنشئ عاملًا آخر يكتب
خارج ترتيب العامل القديم. التنفيذ المعدل يشارك منفذًا واحدًا على مستوى process:

```kotlin
private val disposed = AtomicBoolean(false)
private companion object {
    val worker = ThreadPoolExecutor(
        1, 1, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue<Runnable>(8),
        { task -> Thread(task, "siraj-secure-session").apply { isDaemon = true } },
    )
    const val PAYLOAD_KEY = "encrypted_session_marker"
}
fun dispose() {
    disposed.set(true)
    channel.setMethodCallHandler(null)
}
```

الـPatch الكاملة تضيف فحص disposed قبل العمل والحفظ، وتحجب callback
لـEngine مفصولة. Read/Write/Clear تتسلسل على العامل، لا على Android main
thread؛ النتائج فقط تعود عبر Handler إلى main. الطابور8، ورفض الامتلاء خطأ
عام آمن. Task بدأت داخل عملية commit قد تنتهي؛ العامل المشترك يمنع مهمة
Engine أحدث من تجاوزها، وليس ضمانًا بإيقاف أي native syscall فورًا.

`MainActivity.configureFlutterEngine` يتخلص من القناة السابقة قبل استبدالها،
و`cleanUpFlutterEngine` يحتفظ بالتنظيف الموجود. لا تستبدل Activity المحلية
بكاملها إذا عليها قنوات LLM أو PDF. أبقِ اسم القناة
`siraj/auth_keystore_v1` والطرق `read/write/clear` ونطاقاتها متطابقة بين Dart/Kotlin.

أضيفت حدود Marker4096 وciphertext وUTF-8 صارم، ومهلة Dart15s. فشل decrypt
أو فقد المفتاح أو timeout لا يؤدي إلى دخول أو حذف حساب أو fallback واضح.
Timeout Dart لا يلغي native syscall بذاته؛ Marker المتأخرة لا تمنح جلسة
جديدة دون nonce مطابقة في DB، وترتيب Lane/العامل جزء من ضمان السلامة.

ترتيب إصدار الجلسة **قبل** الإصلاح نشر DB nonce ثم كتب Marker واعتمد على
rollback قابل للفشل. الآن تكتب Marker وتؤكد أولًا، ثم CAS مشروط بالمالك وepoch
وnonce السابقة في معاملة SQLite. المخزنان ليسا transaction ذرية واحدة؛
Marker يتيمة أو قديمة تفشل Guard وينظفها Startup في نفس Lane.

نجاح COMMIT هو حد حسم العملية: Cancel بعده لا يتظاهر بإلغاء كتابة دائمة؛
Logout/Delete المصفوفان يصرفان العملية ويبطلان nonce الناتجة. قبل COMMIT
تُفحص generation داخل المعاملة. عند فشل Logout تبقى سلطة خاصة لـRetry،
والعمليات الحساسة محجوبة محليًا. DD-06: DB invalidation قبل نجاح Logout؛
DD-07: Delete يحذف account-owned rows فقط وتبقى installed_resource.

هذه ضمانات اختُبرت في السحابة بالـSQL والفشل المحقون. Keystore native
وEngine lifecycle وbackup/OEM يحتاج كل منها دليل Android، ولا يستنتج
نجاحه من مراجعة Kotlin أو mock MethodChannel.

## 7. ترتيب النقل اليدوي: افتح، ابحث، عدّل، احفظ، اختبر

لا تنفذ الخطوات على نسخة الهاتف الحالية. احتفظ ببوابة production مغلقة.
قبل نقل SQL طابق: اسم جدول الحساب، owner/epoch، nonce المخزنة SHA256/BLOB،
FK/cascade وسجل الموارد المنفصل. إن اختلفت، اكتب mapping لعقد Repository
المحلي بدل نسخ مخطط Codex أو حذف قاعدة البيانات. قاعدة قديمة تحتاج migration
مراجعة إن تغير مخططها؛ هذه الحزمة لا تقدم migration لمخطط لم نره.

### الخطوة 1 — العامل الجديد

1. ابحث في مشروعك عن worker/Isolate KDF قائم؛ لا تنشئ خدمة مكررة.
2. إن لم يوجد، افتح `lib/features/auth/kdf_worker.dart` كملف جديد، وانقل
   محتوى `new_files/lib/features/auth/kdf_worker.dart.txt` كاملًا بعد مطابقة
   cryptography API. احفظ UTF-8. لا تدخل Kotlin PBKDF2 بالتوازي معه.
3. انقل fixture و`b04_kdf_worker_test.dart`، وعدّل imports فقط إن تغير package.
   يشير الاختبار إلى PasswordHasher؛ أكمل الخطوة2 قبل تشغيله.

### الخطوة 2 — PasswordHasher

1. افتح `password_hasher.dart` وابحث عن `Pbkdf2.hmacSha256` أو `_derive`.
2. افتح Patch المقابلة. أضف import وحقن `IsolatePbkdf2`، وحدود المدخلات
   وcandidate constant، ووسيط `KdfCancellation?` في hash/verify.
3. انقل استدعاء `_worker.derive` في **المسارين**؛ لا تترك Login على provider
   قديم بينما Signup على worker. أبقِ Salt ومعلمات الحسابات القديمة والمقارنة.
4. احفظ، ثم شغل الاختبارين بعد إضافة الملفات المتوافقة:

```powershell
Set-Location -LiteralPath $project
flutter test test/password_hasher_test.dart test/b04_kdf_worker_test.dart
if ($LASTEXITCODE -ne 0) { throw 'عالج اختلاف API أو فشل المتجهات قبل المتابعة.' }
```

إذا `password_hasher_test.dart` غير موجود، شغّل الملف المنقول وحده؛ لا تسمّ
اختبارًا غير موجود PASS. أضف معادلات المتجهات إلى اختباراتك القائمة إن كان
اسم Hasher مختلفًا بدل تغيير API تطبيقك دون حاجة.

### الخطوة 3 — models وLane وGuard

1. افتح `auth_models.dart`: أضف typed busy/cancel/KDF errors إن لم توجد،
   و`accountCreated` بقيمة افتراضيةfalse. لا تسقط حالات فشل محلية موثقة.
2. أضف `auth_operation_lane.dart` كاملًا عند توافق الأنواع؛ مفتاح Lane هو
   **نفس كائن DB** لجميع AuthService/Startup، لا DB جديدة لكل صفحة.
3. افتح `session_guard.dart` وابحث عن `isCurrent`، وانقل حجب الهوية المشترك
   و`matchesPersistedSessionForRevocation`. لا تجعل دالة Retry تصريحًا للقراءة
   أو الحفظ أو Chat. انقل imports SHA256 كما في Patch.
4. احفظ هذه المجموعة مع الخطوتين4/5 قبل الحكم على build؛ العقود مترابطة.

### الخطوة 4 — UserRepository والمعاملات

1. افتح Repository المحلي وابحث عن create و`active_session_nonce_hash`.
2. طابق أعمدة Codex مع مخططك. انقل وسيط `isRequestCurrent` وفحصه داخل
   transaction قبل/بعد INSERT، وأضف `compareAndSetNonceHash` بمعاملته.
3. انقل شرط expectedNonce في invalidate/delete، وأبقِ foreign keys وcascade
   وموارد الجهاز منفصلة. لا تنقل `schema.drift` أو generated DB من المرجع.
4. احفظ؛ راجع عدد الصفوف المتغيرة: يجب أن يكون1 قبل إعلان نجاح الإبطال/الإصدار.

### الخطوة 5 — AuthService دون استبدال أعمى

1. افتح الملف وابحث عن createAccount/login/_createSession/logout/delete/restore.
2. انقل حقول `_lane` وتهيئته من users.db، و`cancelPendingAuthentication`،
   وربط cancellation وgeneration إلى KDF وRepository وفق Patch.
3. انقل إصدار Marker ثم CAS، وexpected previous nonce، وعدم وجود await
   قابل للفشل بين COMMIT الناجح ونشر `_active`. احذف rollback القديم فقط إذا
   حل محله المسار الكامل؛ لا تجمع ترتيبين لإصدار الجلسة.
4. انقل حجب الجلسة عند طلب الإبطال وعند بدء الإجراء المصفوف، واحتفظ بسلطة
   Retry الخاصة عند فشل DB. لا تعرضها عبر activeSession أو Guard.
5. انقل `accountCreated` بعد نجاح INSERT ثم فشل الجلسة، وتنظيف Marker
   best-effort **بعد** إبطال DB. أبقِ المصادقة بكلمة صحيحة مطلوبة للعودة.
6. احفظ ثم انقل support tests وشغّل race/recovery/full-flow. لا تخفض iterations
   الإنتاجية لتنجح؛ اختبارات التزامن تستعمل إعدادًا سريعًا معزولًا فقط.

### الخطوة 6 — Startup وصفحات Auth

1. افتح Startup resolver: اجعل read+cleanup على Lane نفسها؛ نظّف Marker
   غير المطابقة دون اعتبار فشل DB دليلًا على غياب الحساب.
2. افتح Signup/Login، وانقل onCancel وdispose ورسائل الفشل العامة ومسح حقول
   كلمة المرور. Signup الذي حفظ حسابه ينتقل إلى Login بعقد accountCreated.
3. أبقِ handlers الإنتاجية خلف Gate. سيجري تمرير AuthService الحقيقي من
   **المسبار الاختباري** فقط؛ لا تعدّل AppBootstrap لاختبار الهاتف.
4. احفظ وشغّل Widget tests المتوافقة؛ إن تغيرت keys فعدّل selectors في tests
   بما يطابق UI الفعلية، ولا تغيّر assertions الأمنية لتمرير الاختبار.

### الخطوة 7 — Kotlin وManifest

1. افتح Activity المحلية. إن اختلف `package`/`namespace`، احتفظ بهما وانقل
   القناة إلى مسار Kotlin الموافق، مع تطابق اسم class والاستدعاء.
2. افتح `SirajSecureSessionChannel.kt` وادمج Patch: shared bounded executor،
   disposed guards، rejected queue، bounds وUTF-8، debug-only b04_test.
   احتفظ بـAES/GCM ومفاتيح provider ولا ترجع key/marker إلى logs.
   إن لا يوجد هذا class أصلًا، استخدم الكود الكامل المثبت في
   `docs/qa/b04_reference/complete_platform/android/app/src/main/kotlin/com/example/siraj/SirajSecureSessionChannel.kt.txt`،
   مع نقل الملف إلى مسار package المحلي وتعديل سطر package فقط بعد مطابقة
   العقد؛ لا يكفي Patch مبنية على ملف غير موجود لإضافة القناة لأول مرة.
3. انقل dispose السابق في configureFlutterEngine فقط، واحتفظ بباقي قنواتك
   وsuper calls والتنظيف الموجود. لا تجمع flutter_secure_storage والقناة
   المباشرة لكتابة **نفس** Marker؛ إذا مخزنك مختلف فاكتب adapter واحدًا للعقد
   واختبره، ولا تحذف المخزن القديم/المفتاح أو بيانات الحساب كحل تلقائي.
4. افتح Manifest الموجود، وأضف إلى application فقط:

```xml
android:allowBackup="false"
android:fullBackupContent="@xml/backup_rules"
android:dataExtractionRules="@xml/data_extraction_rules"
```

5. أضف XML الكاملين من `new_files/android/app/src/main/res/xml/` مع إزالة
   `.txt`، أو ادمج سياستهما مع قواعدك. لا تكرر attributes ولا تستبدل Manifest.
   هذه التغييرات لا تحتاج plugin تشفير أو dependency جديدة. dataExtractionRules
   تحتاج compileSdk31+؛ إن مشروعك أقدم، وثق ترقية أدوات Android المنفصلة
   أو مكافئ السياسة المدعوم بدل إخفاء خطأ compiler أو تعطيل الحماية.
6. احفظ وابنِ **نسخة الاختبار المعزولة فقط** بعد الخطوة9. نجاح XML unit test
   لا يثبت نجاح Kotlin أو merged manifest أو OEM backup.

إن لم تكن Activity تسجل القناة أصلًا، فهذه الإضافة داخل class Activity
الموجود، بعد إضافة `import io.flutter.embedding.engine.FlutterEngine`:

```kotlin
private var secureSessionChannel: SirajSecureSessionChannel? = null

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    secureSessionChannel?.dispose()
    secureSessionChannel = SirajSecureSessionChannel(
        this, flutterEngine.dartExecutor.binaryMessenger,
    )
    // أبقِ أي تسجيل لقنواتك الأخرى الموجودة هنا.
}

override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
    secureSessionChannel?.dispose()
    secureSessionChannel = null
    super.cleanUpFlutterEngine(flutterEngine)
}
```

ادمج داخل overrides القائمة إن وجدت؛ لا تضف method ثانية بالاسم نفسه، ولا
تغير superclass أو تحذف hooks أخرى. جلسة flutter_secure_storage سابقة لا
تصبح ciphertext القناة الجديدة تلقائيًا؛ اختبر التوافق أو اطلب Login
صحيحة لاستعادة الجلسة وفق العقد، دون حذف الحساب/DB أو تجاوز كلمة المرور.

### الخطوة 8 — حراسة المحادثة وB-08

1. افتح first USER transaction وcontroller، وانقل sessionNonceHash وفحص
   `isRequestCurrent`/الحجب داخل transaction، لا مجرد فحص قبل await.
2. إذا لديك B-08، احتفظ بـsaveFirstUserMessageWithOutcome، IDs الثابتة
   لإعادة المحاولة، eviction outcome، follow-up، reply-id fence وwatchSession.
   اجمع callback الجيل مع حجب SessionGuard؛ أحدهما لا يغني عن الآخر.
3. في Codex توجد تعارضات نصية مثبتة مع PR #4 في ثلاثة ملفات:
   UserRepository وConversationRepository وConversationDraftController.
   ليست هناك نتيجة دمج ناجحة أو suite مشتركة. لا تنسخ Controller القديم لمسار B-05 وحراسة B-04 فوق B-08.
4. احفظ ثم شغّل late-message وrace/history/retry/logout/delete في اختباراتك؛
   أضف assertions للـnonce داخل المعاملة إذا لم توجد. لا تعلن توافق B-08
   قبل حل التعارضات وتشغيل اختبارات الفرعين على نتيجة التسوية.

### الخطوة 9 — أدوات الاختبار وعزل APK

1. أضف `integration_test/support/b04_probe_app.dart` و
   `integration_test/b04_android_kdf_metrics_test.dart` و
   `integration_test/b04_android_probe_ui_test.dart` من checkout المرجعي؛
   عدّل imports/adapter DB إذا كانت APIs المحلية مختلفة. المسبار يستعمل
   `driftDatabase(name: 'siraj_b04_probe')` وقناة b04_test، ولا يمس DB الإنتاجية.
2. إن لا يوجد Drift/هذه العقود في مشروعك، لا تضف schema Codex كاملًا لتشغيل
   المسبار: جرّبه أولًا في checkout Codex المستقل، ثم اكتب adapter اختبار
   لتخزينك المحلي مع نفس الضمانات. قياس KDF المستقل يمكن نقله دون DB.
3. تحقق من `pubspec.yaml`. المرجع اختُبر مع Dart3.10.4 وcryptography2.9.0،
   drift2.33.0 وdrift_flutter0.3.1، وintegration_test من Flutter SDK. هذه
   **نسخ التحقق** وليست أمرًا بترقية تبعيات مشروعك كلها.
4. إن `integration_test` غير موجود، أضفه عمدًا تحت dev_dependencies:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

إضافة dependency جديدة تستلزم تحديث lockfile مقصودًا ومراجعته. لا تمسحه ولا
تستخدم pub upgrade. عند فشل `--enforce-lockfile` بسبب التغيير المقصود فقط،
شغّل pub get دون enforce مرة واحدة، وراجع diff ثم ثبّت lockfile الجديد قبل
متابعة الاختبارات. فشل بسبب شبكة/SDK ليس سببًا لتحديث القفل.

5. في `android/app/build.gradle.kts` **داخل buildTypes** أضف/ادمج إعداد debug:

```kotlin
getByName("debug") {
    applicationIdSuffix = ".local.b04verification"
    versionNameSuffix = "-b04-test"
}
```

في Groovy `android/app/build.gradle` المكافئ:

```groovy
debug {
    applicationIdSuffix '.local.b04verification'
    versionNameSuffix '-b04-test'
}
```

لا تضف debug مرتين إن كان موجودًا؛ ادمج الحقول. احتفظ بـnamespace وpackage
Kotlin وMainActivity؛ تغيير applicationId للاختبار لا يعني تغيير package
الكود. إذا لديك flavors/suffixes قائمة، احسب ID النهائي من variant الفعلي
ووثقه؛ لا تفترض أن ناتج المثال سيطابقه. تغييرات هذه الفقرة **للفرع المحلي
التجريبي فقط**، ولم تُدخل في ملفات Gradle الإنتاجية في PR #5.

المثال عندما defaultConfig.applicationId هو `com.example.siraj` يعطي
`com.example.siraj.local.b04verification`. أعطِ تثبيت الاختبار اسم launcher واضحًا
مثل `SIRAJ B04 TEST` في فرع التجربة إن أردت تجنب الالتباس؛ راجع Manifest merge.
لا تشغّل flutter run/test integration قبل فحص APK وID كما يلي.

استخدم suffix مختلفة لمرجع Codex المحلي مثل `.codex.b04verification` إن
ستجربه أيضًا، واضبط `$project` و`$probeId` له صراحة. APK Actions المنشورة
تستعمل `com.example.siraj.b04verification`؛ ليست نسخة مشروعك الأصلي. لا تخلط
هذه التثبيتات الثلاثة أو قواعد بياناتها. مفاتيح debug signing قد تختلف بين
Windows وActions وبين runners؛ `INSTALL_FAILED_UPDATE_INCOMPATIBLE` لا يعالج
بحذف بيانات التطبيق الحالي أو مفاتيحه. احتفظ بـID مستقلة ومصدر توقيع متسق
لكل تجربة، ولا تثبت APK من مصدر آخر فوق package قائمة مجهولة.

## 8. أوامر Windows: SDK وFlutter والاختبارات

### أ. تجهيز الأدوات الرسمية

ثبت Android Studio من [المصدر الرسمي](https://developer.android.com/studio)،
ثم SDK Manager: Android SDK Platform/Build-Tools وPlatform-Tools وCommand-line
Tools. لا تحمل SDK أو DLL تشفير من روابط مجهولة ولا تعطل TLS. إذا يوجد SDK
صالح فلا تعِد تثبيته. مرجع Codex يحتاج JDK17 وأدوات متوافقة مع AGP8.11.1؛
لا تنقل Gradle/JDK إلى مشروعك دون مراجعة توافق نسختك.

```powershell
Set-Location -LiteralPath 'D:\SIRAJ\App Flutter'
flutter --version
dart --version
java -version
flutter doctor -v
$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
if (-not (Test-Path -LiteralPath $sdkRoot)) { throw 'حدد SDK الفعلي من Android Studio.' }
$env:ANDROID_HOME = $sdkRoot
$env:PATH = "$sdkRoot\platform-tools;$sdkRoot\cmdline-tools\latest\bin;$env:PATH"
flutter config --android-sdk "$sdkRoot"
sdkmanager.bat --list_installed
flutter doctor --android-licenses
flutter doctor -v
```

راجع التراخيص بنفسك. إن `sdkmanager.bat` غير موجود، ثبت Command-line Tools
من SDK Manager وحدد مسار الإصدار الموجود بدل تخمينه. لمرجع Flutter3.38.5
يمكن تثبيت الأدوات الرسمية اللازمة بالمثال التالي؛ NDK يحدده مشروع Flutter
والـbuild log، ولا يخمّن من رقم هاتفك:

```powershell
sdkmanager.bat 'platform-tools' 'platforms;android-36' 'build-tools;35.0.0'
if ($LASTEXITCODE -ne 0) { throw 'فشل تنزيل SDK؛ سجل hostname/status الفعلي دون تعطيل الحماية.' }
```

فعّل Developer options/USB debugging في Samsung، ووصل USB ووافق على بصمة
الكمبيوتر الموثوق على الهاتف. هذه خطوات ستنفذها أنت؛ Codex لا يتصل بجهازك.

```powershell
adb devices -l
flutter devices
$device = Read-Host 'أدخل ID هاتف الاختبار كما ظهر، وليس emulator أو جهازًا آخر'
adb -s $device shell getprop ro.product.model
adb -s $device shell getprop ro.build.version.release
adb -s $device shell getprop ro.product.cpu.abi
adb -s $device shell cat /proc/meminfo
```

سجل model/OS/ABI/RAM ونسخة Flutter/SHA فقط. احذف serial/مسارات حساب Windows
من أي تقرير مرسل. إذا unauthorized، عالج موافقة USB؛ لا تنفذ الاختبارات على
device آخر افتراضيًا ولا تعتبر Emulator دليل Samsung.

### ب. dependencies والتحقق السحابي/المضيف

```powershell
Set-Location -LiteralPath $project
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { throw 'توقف: ميّز اختلاف lockfile المقصود عن فشل الشبكة/SDK.' }
git diff -- pubspec.yaml pubspec.lock
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'عالج التحليل قبل تجربة الهاتف.' }
flutter test
if ($LASTEXITCODE -ne 0) { throw 'الاختبارات الكاملة لم تنجح.' }
$focused = @(
  'test/password_hasher_test.dart', 'test/auth_service_test.dart',
  'test/b04_kdf_worker_test.dart', 'test/b04_auth_race_test.dart',
  'test/b04_security_recovery_test.dart', 'test/b04_cross_store_recovery_test.dart',
  'test/b04_full_flow_test.dart', 'test/b04_auth_real_widget_test.dart',
  'test/b04_keystore_channel_test.dart', 'test/b04_late_message_test.dart',
  'test/b04_backup_policy_test.dart', 'test/b04_probe_app_test.dart'
)
foreach ($file in $focused) {
  if (-not (Test-Path -LiteralPath $file)) { throw "اختبار غير موجود/لم ينقل بعد: $file" }
}
flutter test --no-pub @focused
if ($LASTEXITCODE -ne 0) { throw 'فشل تحقق B-04 المركّز.' }
dart run tool/b04_kdf_benchmark.dart
```

القائمة تخص المرجع مع ملفات هذه المتابعة. إذا اختباراتك بأسماء أخرى، وثق
mapping وشغّل ما أُضيف وتكيّف فعلًا؛ لا تحذف اختبارًا من قائمة الإنجاز
وتدّعي أنه نجح. `dart run` أعلاه يقيس **Windows host**، وليس الهاتف المتصل.
اختبار الهاتف الحقيقي التالي يقيس Android. لا توجد DLL منقولة من Linux:
SQLite native يجب أن تبنى/تنزل للـABI المستهدف عبر dependencies المعتمدة.

### ج. بناء APK معزول وفحص هويته قبل أي تثبيت

```powershell
$evidence = "D:\SIRAJ\B04-evidence-$stamp"
New-Item -ItemType Directory -Path $evidence | Out-Null
flutter build apk --debug --no-pub --target integration_test/support/b04_probe_app.dart
if ($LASTEXITCODE -ne 0) { throw 'لا APK صالح؛ لا تتابع إلى التثبيت.' }
$apk = Join-Path $project 'build\app\outputs\flutter-apk\app-debug.apk'
$aapt = Join-Path $sdkRoot 'build-tools\35.0.0\aapt.exe'
if (-not (Test-Path -LiteralPath $aapt)) { throw 'حدد aapt من Build-Tools المثبتة.' }
$badging = & $aapt dump badging $apk
if ($LASTEXITCODE -ne 0) { throw 'تعذر فحص APK.' }
$actualId = [regex]::Match(($badging | Select-Object -First 1), "name='([^']+)'").Groups[1].Value
$baseId = 'com.example.siraj' # غيّره إلى applicationId الأصلي الذي سجلته قبل تعديل debug.
$probeId = "$baseId.local.b04verification" # طابق variant الفعلي إن لديك flavors؛ Codex reference تستعمل suffix مستقلة.
if ($actualId -ne $probeId -or $actualId -eq $baseId -or -not $actualId.EndsWith('.b04verification')) {
  throw "هوية APK غير آمنة/غير متوقعة: $actualId؛ لا تثبته."
}
adb -s $device shell pm list packages $baseId
adb -s $device shell pm path $probeId
Copy-Item -LiteralPath $apk -Destination "$evidence\b04-probe-debug.apk"
Get-FileHash -LiteralPath "$evidence\b04-probe-debug.apk" -Algorithm SHA256
```

إذا وجدت package الاختبار مثبتة قبل أول تجربة، **توقف وتحقق أنها تثبيت
اختبارك السابق**؛ لا تكتب فوق تطبيق مجهول. ID مختلف شرط أقوى من اختلاف
اسم الأيقونة. لا uninstall أو `pm clear` أو حذف Keystore لأي تطبيق قائم.
لا تستخدم `flutter run` الافتراضي؛ اختباره قد يستهدف `lib/main.dart`/ID آخر.
لو بنيت flavor فمسار APK مختلف؛ اختر الناتج الحقيقي وافحص ID، ولا تتجاوز
الشرط لتنجح الأوامر.

### د. اختبارات Android الآلية، ثم إعادة تثبيت المسبار اليدوي

بعد إثبات عزل ID ومطابقة Gradle لكل debug targets، شغّل:

```powershell
flutter test integration_test/b04_android_secure_session_test.dart -d $device --no-pub --reporter expanded
if ($LASTEXITCODE -ne 0) { throw 'فشل native session acceptance؛ احفظ الخطوة والخطأ المنقحين.' }
flutter test integration_test/b04_android_kdf_metrics_test.dart -d $device --no-pub --reporter expanded
if ($LASTEXITCODE -ne 0) { throw 'فشل قياس/إلغاء KDF على Android؛ لا تعتمد الإعداد.' }
flutter test integration_test/b04_android_probe_ui_test.dart -d $device --no-pub --reporter expanded
if ($LASTEXITCODE -ne 0) { throw 'فشل UI/SQLite/Keystore الحقيقي؛ لا تعلن نجاح مسار الهاتف.' }
```

الأول يستخدم Keystore الحقيقي وSQLite مؤقتة: إنشاء/كلمة خاطئة/صحيحة/
reopen/Logout/Login/Delete وبقاء سجل مورد. الثاني ثلاث عينات600000 مع
heartbeat/RSS وإلغاء. طباعات `SIRAJ_B04_METRICS` بيانات synthetic فقط.
SQLite reopen في الأول **ليس** Force-stop/reboot. لا تختصر timeout بخفض
iterations إذا تأخر الهاتف؛ سجل الفشل والأداء للمراجعة.
الثالث يقود Signup والتحميل وكلمة خاطئة وصحيحة وLogout/Delete عبر UI الحقيقية،
ويحفظ محادثة ورسالة USER ليثبت cascade عند الحذف مع بقاء المورد. لا يستدعي
Tutor ولا يعرض إجابة علمية اصطناعية. نجاحه يخص السيناريو المختبر، وليس
اختبار lifecycle/backup أو إثبات عدم ANR مطلقًا.

هذه الاختبارات تنظف نطاق `b04_test`؛ نفذها **قبل** إنشاء حساب المسبار
اليدوي. APK integration قد يستبدل entry point الاختباري بنفس ID المعزولة،
لذلك أعد تثبيت نسخة المسبار المحفوظة بعد التحقق أعلاه فقط:

```powershell
adb -s $device install -r "$evidence\b04-probe-debug.apk"
if ($LASTEXITCODE -ne 0) { throw 'فشل تثبيت مسبار الاختبار.' }
$activity = (adb -s $device shell cmd package resolve-activity --brief $probeId | Select-Object -Last 1).Trim()
if (-not $activity.StartsWith("$probeId/")) { throw 'Launcher غير متوقع؛ لا تشغل Activity مخمنة.' }
adb -s $device shell am start -n $activity
```

`-r` هنا لتحديث **package الاختبار المؤكدة** بعد integration، وليس إذنًا
لاستبدال التطبيق الحالي. إن لم تنقل المعمارية بعد، نفذ هذه الدورة في checkout
Codex المستقل أولًا بنفس شروط العزل، ثم طبقها على نسختك بعد تكييف العقود.

## 9. تجربة Samsung اليدوية والسجلات

المسبار لا يشغّل Gate الإنتاجية. عنوانه B-04 غير إنتاجي؛ يستخدم الصفحات
الحقيقية وAuthService/SQLite/Keystore، وقاعدة مختلفة ثابتة تستمر بعد إغلاق
process. لا يوجد Fake Tutor أو Fake Storage في entry point.

افتح نافذة PowerShell ثانية بعد تشغيله:

```powershell
$device = Read-Host 'نفس ID الهاتف'
$probeId = 'com.example.siraj.local.b04verification' # ID المؤكد من APK، لا تنسخه إذا كان مشروعك مختلفًا أو تختبر artifact Codex.
$evidence = Read-Host 'المسار الكامل لمجلد B04-evidence الذي أنشأته'
$probePid = (adb -s $device shell pidof -s $probeId).Trim()
if (-not $probePid) { throw 'شغّل المسبار أولًا.' }
adb -s $device logcat --pid=$probePid -v threadtime > "$evidence\probe-logcat.txt"
# أوقف الجمع بـCtrl+C بعد سيناريو محدود؛ لا تجمع سجل الهاتف كله.
```

سجل PID جديد بعد Force-stop/reboot؛ PID قديم لا يراقب process الجديدة.
في نافذة التحكم، دون مسح logcat أو بيانات أي تطبيق:

```powershell
adb -s $device shell dumpsys meminfo $probeId > "$evidence\meminfo-before.txt"
adb -s $device shell dumpsys gfxinfo $probeId framestats > "$evidence\frames-before.txt"
# بعد إنشاء الحساب/الدخول والإلغاء والتكرار:
adb -s $device shell dumpsys meminfo $probeId > "$evidence\meminfo-after.txt"
adb -s $device shell dumpsys gfxinfo $probeId framestats > "$evidence\frames-after.txt"
adb -s $device logcat -b events -d -s am_anr | Select-String -SimpleMatch $probeId
```

لا تعتبر عدم وجود سطر am_anr وحده إثباتًا لعدم وجود تجمد؛ قد تكون نافذة
التسجيل قصيرة أو بعض سجلات النظام غير متاحة. قارن Loading/التمرير/Cancel
وframe timings والفترة المسجلة. `signup_kdf_ms` يقيس الاشتقاق، و
`login_total_ms` يقيس Login كله بما فيه DB/Keystore؛ لا تقارن الرقمين كأنهما
المقياس نفسه. RSS للعملية كلها، وليس worker heap ولا إثبات leak-free.

إعادة تشغيل process دون حذف بيانات:

```powershell
adb -s $device shell am force-stop $probeId
adb -s $device shell am start -n $activity
```

إعادة تشغيل الهاتف خطوة يدوية لاحقة بعد حفظ العمل وإيقاف logs. لا يلزم
أمر reboot تلقائي. افتح المسبار بالـID المعزولة بعد الإقلاع وتحقق من الجلسة.
لا تلمس تثبيت سراج الأصلي أو حسابه أو بياناته.

## 10. مصفوفة القبول: سجل PASS/FAIL/PENDING لكل صف

| الاختبار | خطوات التنفيذ | النتيجة وكيف يثبت النجاح | عند الفشل: الدليل المنقح |
|---|---|---|---|
| البناء والعزل | بناء debug probe؛ aapt ثم مقارنة ID | APK صالح وID مختلفة قبل install | أول خطأ compiler، Flutter/JDK/AGP/SDK، لا local.properties |
| التشغيل | افتح ID المعزولة والعنوان B-04 | شاشة الاختبار وليس التطبيق الحالي؛ لا crash | نوع الخطأ وstack مقتضبة بلا بيانات حساب |
| Signup | اسم/كلمة اختبار من عندك وتأكيد مطابق | جلسة اختبار نشطة، account واحد، لا معلومات خاصة في logs | آخر `SIRAJ_B04_CORE step` وtyped error فقط |
| KDF والاستجابة | نفذ metrics، وراقب Loading/التمرير/Cancel أثناء Signup |600000 فعلية، UI تستجيب؛ أوقات3عينات وframe data موثقة | metrics/ANR window/CPU-RAM، لا كلمة أو hash |
| الإلغاء وإعادة المحاولة | Cancel أثناء KDF ثم retry؛ كرر | لا حساب قبل COMMIT؛ إن حفظ الحساب قبل الإلغاء انتقل Login، ولا duplicate | step/timing/code وحالة وجود الحساب فقط |
| كلمة صحيحة/خاطئة | Logout ثم Login خاطئة فصحيحة | الخطأ لا ينشئ session؛ الصحيحة فقط تدخل | error code والفترة دون المدخلات |
| استمرار الجلسة | Force-stop ثم فتح، ثم reboot يدوي وفتح | جلسة صحيحة تستعاد عبر native Keystore وDB نفسها | startup status وnative error code؛ لا Marker/nonce |
| Logout | اخرج ثم Force-stop وافتح | Login مطلوب؛ session القديمة لا تعود | native test وخطوة الإبطال، لا DB dump |
| Login مجددًا | بعد الخروج، كلمة الاختبار الصحيحة | جلسة جديدة فقط؛ لا old session revival | typed failure ونسخة الكود |
| Delete والموارد | أضف سجل المورد MISSING في المسبار؛ سجل العدد؛ أكد Delete | Signup يعود وعدد الموارد يبقى؛ basic session test لا يثبت child cascade، بينما probe UI test يزرع محادثة وUSER ويختبر حذفيهما فعلًا | عدد الصفوف/المورد قبل/بعد، لا محتوى محادثة |
| تزامن/كتابة متأخرة | race/late-message unit tests؛ لا تضغط يدويًا وتحكم وحده | رفض الطلب المتداخل وكتابة nonce قديمة، لا duplicate USER | اسم assertion الفاشلة وتواقيت الطلبات الاصطناعية |
| فشل DB/التخزين | recovery/cross-store/channel tests؛ ثم عطل native معزول إن جهز fixture مراجعة | لا نجاح كاذب؛ حجب حساس وRetry؛ لا حذف للحساب | نطاق الاختبار/مرحلة fault؛ لا مفاتيح أو ciphertext |
| Lifecycle | rotate/Activity recreation أثناء العملية ثم reopen | لا callback قديم يطغى على Marker أحدث أو thread متراكم | logs مقتضبة/وصف الخطوات؛ يظل PASS بحاجة إلى تنفيذ فعلي |
| Keystore/backup | native اختبار أولي؛ فقد مفتاح/OEM transfer يحتاجان fixture/جهازين لاحقًا | لا plaintext fallback؛ لا session غير مطابقة؛ merged manifest صحيح | AndroidKeystoreException code منزوع النص الخاص؛ لا key dump |
| تكرار/ذاكرة |5دورات Login/Logout وإلغاء على الأقل مع نفس ظروف الجهاز | جميع الدورات مكتملة؛ لا تدهور مستمر ملحوظ مع حفظ المقاييس | أزمنة متتابعة وmeminfo/gfxinfo قبل/بعد؛5دورات لا تثبت انعدام التسرب |
| B-08/SQLite | تسوية التعارضات في فرع منفصل وتشغيل suites الفرعين | history/follow-up/retry/session guards تعمل بعد التسوية | files/line/اختبار؛ لا ادعاء نجاح قبل suite مشتركة |

اختبارات فشل Keystore/فقد المفتاح/تلف ciphertext على جهاز حقيقي **ليست**
موجودة تلقائيًا في زر بالمسبار. لا تحذف alias أو تعدل Prefs بطرق عشوائية
على الهاتف. اختبارات السحابة تحقن الأعطال في support fakes فقط؛ هذه الصفوف
تظل PENDING_DEVICE_TEST إلى أن يوجد fixture Android معزول ومراجع وتنفذه.

## 11. المقارنة بين البيئات وما ترسله عند المشكلة

| البيئة | ما يثبت منها | ما لا يستنتج منها |
|---|---|---|
| Codex Linux | vectors، KDF مع isolate/cancel، DB فعلية وreopen، races، Flutter widgets، analyze/test | native Keystore أو Samsung ANR/backup/reboot |
| GitHub-hosted Android Emulator | فقط الخطوات الناجحة الموثقة في run المرتبط بالتقرير | قوة hardware Keystore أو Samsung/OEM/6GB أو اعتماد إنتاجي |
| Samsung SM-N986U Android13 | يبدأ كله PENDING إلى أن تنفذ أنت وتوثق | لا يرث PASS من السحابة أو Emulator |
| تطبيقك الأصلي | نتائج التكييف اليدوي واختبارات نسخته فقط | لا نفترض تطابقه أو حداثته مقابل Codex |

إن فشل سيناريو، أرسل نسخة **منقحة** تحتوي: SHA/branch، إصدار Flutter/Dart
وAndroid/JDK/SDK، model/OS/ABI/RAM، اسم السيناريو ونتيجته، الوقت والخطوة
الأخيرة، نوع الخطأ وstack مقتضبة، ومقاييس KDF/frames/الذاكرة ذات الصلة.
احذف كلمات المرور/username/nonce/Marker/hash/private key/serial/مسارات حساب
Windows وأي signed URLs أو tokens. لا ترسل DB أو SharedPreferences أو
Logcat كاملًا؛ راجع الملف بنفسك قبل رفعه. لا ترسل أسرارًا لحل خطأ وصول.

قبل حفظ التغييرات المحلية، راجع `git diff --check` و`git diff --stat` وكل
ملف منفردًا. Commit انتقائي لإصلاح B-04، وCommit منفصل لإعداد الاختبار المعزول.
لا ترفع مفاتيح debug الخاصة أو APK/DB/SDK/cache إلى مستودعك دون مراجعة.
لا تفتح production Gate حتى تُراجع نتائج Android وإعداد KDF وفق DD-05؛
نجاح هذه التجربة ليس تصريحًا بدمج PR أو إطلاق نسخة إنتاجية تلقائيًا.
