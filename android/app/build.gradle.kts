import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名：优先读 android/key.properties（已 gitignore，勿提交密钥）。
// 也支持 CI 注入环境变量 RELEASE_*（见 .github/workflows/ci.yml 注释与 README「发布签名」）。
// 两者都没有时，release 回退 debug 签名并打印警告 —— 仅供本地自用，**禁止上架商店**。
val keystoreProperties = Properties().apply {
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        FileInputStream(keyPropsFile).use { load(it) }
    }
}

fun prop(name: String): String? {
    // key.properties 用 storeFile/storePassword/keyAlias/keyPassword；
    // 环境变量用 RELEASE_STORE_FILE 等（CI Secrets 习惯）。
    val envName = "RELEASE_" + name.replace(Regex("([a-z])([A-Z])"), "$1_$2").uppercase()
    return keystoreProperties.getProperty(name)
        ?: System.getenv(envName)
        ?: System.getenv(name)
}

val hasReleaseSigning: Boolean =
    !prop("storeFile").isNullOrBlank() &&
        !prop("storePassword").isNullOrBlank() &&
        !prop("keyAlias").isNullOrBlank() &&
        !prop("keyPassword").isNullOrBlank()

android {
    namespace = "com.davidche1116.sms"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.davidche1116.sms"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // 插件已预置默认 ABI 列表，需先清空再设置（buildType 级 abiFilters 在 AGP 9 下不生效）
            abiFilters.clear()
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                // storeFile 相对 android/app/ 解析；也可写绝对路径。
                storeFile = file(prop("storeFile")!!)
                storePassword = prop("storePassword")
                keyAlias = prop("keyAlias")
                keyPassword = prop("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // 无 key.properties / RELEASE_* 时回退 debug 签名，便于本地 `flutter build apk --release`。
                // 注意：debug 签名的包**不能**上架 Google Play / 各商店，也不能作为正式升级包分发。
                // 正式发布前请按 README「发布签名」配置 android/key.properties。
                logger.warn(
                    "WARNING: release build is signed with the DEBUG keystore " +
                        "(no android/key.properties and no RELEASE_* env). " +
                        "Do NOT ship this APK to any store. See README 发布签名."
                )
                signingConfigs.getByName("debug")
            }
        }
    }

    testOptions {
        unitTests {
            // android.util.Log 等桩方法返回默认值而不是抛 Stub!，便于纯 JVM 单测。
            // 不开 includeAndroidResources：会与 Flutter 的 copyFlutterAssetsDebug
            // 产生任务依赖校验冲突，而本套测试用 FakeCursor/Mock 并不需要资源。
            isReturnDefaultValues = true
        }
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.14.2")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.4.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
