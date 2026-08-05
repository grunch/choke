import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseKeystoreFile =
    keystoreProperties["storeFile"]?.toString()?.let { file(it) }
val hasReleaseKeystore = releaseKeystoreFile?.exists() == true

/// Opt in to a debug-signed release: `flutter build apk --release -PdebugSignRelease`.
///
/// The VALUE is what counts, not the presence of the flag: `-PdebugSignRelease=false`
/// has to mean false, or a `gradle.properties` line someone added months ago
/// silently keeps the guard down forever. Bare `-PdebugSignRelease` (no value)
/// still means true, which is how everyone expects a Gradle flag to read.
val debugSignRelease = (project.findProperty("debugSignRelease") as String?)
    ?.let { it.isEmpty() || it.toBoolean() } == true

/// Every Android ABI the toolchain can produce, in the order Gradle names them.
val ALL_ABIS = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")

/// The ABIs a release build packages. Override with `-PchokeAbis=arm64-v8a`
/// (comma-separated) for a single-architecture build.
///
/// The DEFAULT includes 32-bit ARM, and that default is the one Google Play
/// gets. Play splits an App Bundle per device, so an extra ABI in the bundle
/// costs a user on arm64 exactly nothing at install time — while leaving it out
/// costs every 32-bit user the app entirely. That is not a hypothetical: the
/// Galaxy A13 4G (SM-A135F/M, SM-A137F) — one of the best-selling phones in
/// Latin America — has a 64-bit SoC but ships a 32-bit Android userspace, so
/// Play served it "your device isn't compatible" for as long as the bundle was
/// arm64-only. The same is true of much of the entry-level Galaxy A and
/// Android Go range.
///
/// The sideload APK on GitHub Releases is the case that DOES pay per ABI: it is
/// one file containing all of them, and since the Nostr stack became a Rust
/// library that is a full copy of the crate each time (~40 MB across three).
/// That build passes `-PchokeAbis=arm64-v8a` explicitly — see the release
/// workflow. Anyone refereeing off a sideloaded APK is on arm64.
///
/// x86_64 stays out of the default: it means Chromebooks and emulators, and an
/// emulator runs debug builds, which are never filtered.
val DEFAULT_RELEASE_ABIS = listOf("arm64-v8a", "armeabi-v7a")

val releaseAbis = (project.findProperty("chokeAbis") as String?)
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }
    ?: DEFAULT_RELEASE_ABIS

// An empty list is NOT the default — the elvis above only catches an unset
// property, so `-PchokeAbis=` or a stray `-PchokeAbis=,` lands here instead.
// Left alone it produces a release that looks built and is not: `abiFilters`
// with nothing in it filters nothing, while the jniLibs rule below subtracts
// from ALL_ABIS and so strips every prebuilt .so a plugin AAR shipped. Fail.
if (releaseAbis.isEmpty()) {
    throw GradleException(
        "-PchokeAbis was set but named no ABI. Pass a comma-separated list " +
            "(e.g. -PchokeAbis=arm64-v8a), or omit the property entirely to " +
            "get the default: ${DEFAULT_RELEASE_ABIS.joinToString(", ")}."
    )
}

// A typo here is invisible until a device is missing from Play weeks later:
// `abiFilters += "arm64"` silently matches nothing and packages no native code
// at all. Fail the build instead.
val unknownAbis = releaseAbis - ALL_ABIS.toSet()
if (unknownAbis.isNotEmpty()) {
    throw GradleException(
        "Unknown ABI(s) in -PchokeAbis: ${unknownAbis.joinToString(", ")}.\n" +
            "Valid values are: ${ALL_ABIS.joinToString(", ")}"
    )
}

// Refuse to BUILD a release we cannot sign properly — and refuse it here, when
// the task graph is known, rather than while configuring: a check in the
// `release {}` block runs for every build in the project, so it would break
// `flutter run` for anyone without a keystore.
//
// What it prevents: a silently debug-signed `app-release.apk`. It looks like a
// real release and installs like one, but the debug key is regenerated per
// machine (and per run on a CI runner), so once it is on a phone, every genuine
// release afterwards is rejected — an update must carry the same signature as
// the install it replaces. The only way out is uninstalling, which here means
// losing the nsec.
gradle.taskGraph.whenReady {
    if (hasReleaseKeystore || debugSignRelease) return@whenReady

    val buildingRelease = allTasks.any { task ->
        task.project.path == ":app" &&
            Regex("^(assemble|bundle|package).*Release$").matches(task.name)
    }
    if (buildingRelease) {
        throw GradleException(
            "No release keystore: expected android/key.properties pointing at one " +
                "(CI writes it from the KEYSTORE_BASE64 secret).\n" +
                "To build a release locally without it, pass -PdebugSignRelease — the " +
                "result is DEBUG-SIGNED, cannot update a real install, and must never be " +
                "distributed."
        )
    }
}

android {
    namespace = "io.protolayer.choke"
    compileSdk = flutter.compileSdkVersion
    // Pinned rather than inherited from `flutter.ndkVersion`: Cargokit builds
    // the Rust crate through the NDK, and CI installs this exact version by
    // reading it back from this line. A Flutter upgrade that moved the NDK
    // underneath us would otherwise break the build with a bare NPE.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "io.protolayer.choke"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseKeystoreFile?.exists() == true) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = releaseKeystoreFile
                storePassword = keystoreProperties["storePassword"] as String
            }

            // Sign with v3 as well as v2 — releases were coming out v2-only.
            //
            // v3 is the scheme that carries a signing-key LINEAGE, and it is
            // the only way a signing key is ever replaceable: with it, a future
            // keystore can prove it descends from this one, and phones accept
            // the update. Without it, the key below is Choke's identity
            // forever, and losing it means every user reinstalls from scratch —
            // which, since the nsec lives in app storage, means every user
            // loses their identity too.
            //
            // Costs nothing: v3 is additive, the APK stays installable on
            // anything that took the v2-only ones.
            //
            // v1 (JAR signing) stays off. It only matters below API 24 and
            // minSdk is 24.
            enableV1Signing = false
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        debug {
            // A debug build installs as a SEPARATE app, beside the real one.
            //
            // Without this, `flutter run` overwrites the release install — same
            // id, but signed with the machine's debug key. Android then refuses
            // every future release, and the only way out is uninstalling and
            // losing the app's data, which here is the nsec. Developing on the
            // phone you referee with should not cost you your identity.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }

        release {
            // Fail rather than fall back to the debug key.
            //
            // The fallback used to be silent, and it produced a file called
            // `app-release.apk` signed with a key that is regenerated per
            // machine — and, on a CI runner, per run. Install one of those and
            // every real release afterwards is rejected, because an update must
            // carry the same signature as the install it replaces. A build that
            // cannot sign properly should say so, not hand over a poisoned
            // artifact that looks exactly like a good one.
            //
            // Escape hatch for a contributor with no keystore:
            //   flutter build apk --release -PdebugSignRelease
            // What that produces is fine to run and must never be distributed.
            //
            // The refusal itself lives in `assembleRelease` below, NOT here:
            // this block runs at CONFIGURATION time, so throwing from it would
            // fail every build in the project — `flutter run` included — for
            // anyone without a keystore. That is a worse footgun than the one
            // being fixed.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Narrow the release to `releaseAbis`. `flutter build apk
            // --target-platform android-arm64` only narrows Flutter's own
            // libraries — it does not stop Cargokit from building the Rust
            // crate for every Android ABI. This does.
            //
            // Debug keeps every ABI on purpose: filtering it would break an
            // x86_64 emulator at runtime, with an UnsatisfiedLinkError and no
            // hint as to why.
            ndk {
                abiFilters += releaseAbis
            }
        }
    }
}

// `abiFilters` above does not reach native code that arrives *prebuilt* inside
// a plugin's AAR: ML Kit's barcode scanner (the QR reader on the Account
// screen) was still shipping 8.8 MB of x86_64 and armeabi-v7a libraries into
// arm64-only releases. This drops whatever `releaseAbis` did not ask for, so
// the two mechanisms cannot disagree — an AAR ABI that outlives the filter is
// exactly how the bundle ends up carrying architectures the app cannot run.
//
// Scoped to the release variant, not to the Gradle invocation. Keying off the
// task names would flip this on for debug too the moment anything built both in
// one run (`gradle build` does), and the emulator would break for reasons the
// build output would never explain.
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        val excluded = ALL_ABIS - releaseAbis.toSet()
        variant.packaging.jniLibs.excludes.addAll(excluded.map { "**/$it/**" })
    }
}

flutter {
    source = "../.."
}
