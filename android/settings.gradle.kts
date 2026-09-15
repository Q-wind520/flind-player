pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // The Chinese mirrors below are for local (China-network) builds only.
        // On CI they are skipped: a mirror returning 5xx aborts Gradle's
        // resolution instead of falling back, and the canonical repositories
        // are reliable from GitHub runners.
        val onCi = System.getenv("CI") == "true"
        if (!onCi) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
        }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // Local builds use the flutter-io.cn engine mirror and the Chinese
        // Maven mirrors; CI uses the canonical Google engine repository and
        // drops the mirrors (same 5xx-abort reasoning as pluginManagement).
        val onCi = System.getenv("CI") == "true"
        maven {
            url = uri(
                if (onCi) {
                    "https://storage.googleapis.com/download.flutter.io"
                } else {
                    "https://storage.flutter-io.cn/download.flutter.io"
                }
            )
        }
        if (!onCi) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
        }
        google()
        mavenCentral()
    }
}

include(":app")
