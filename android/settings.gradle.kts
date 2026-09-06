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
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // Kotlin 2.1: حزم Firebase الحديثة تستدعي `JvmTarget.fromTarget` التي لا
    // وجود لها في 1.9.25، فيفشل البناء عند تقييم مشروع firebase_core. وFlutter
    // نفسه ينبّه أن دعم ما دون 2.1.0 يوشك أن يسقط.
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // إضافة Google Services: تقرأ google-services.json وتولّد إعداد Firebase
    // في وقت البناء. بدونها يُقلع التطبيق ويرمي «No Firebase App» عند أوّل
    // استدعاء، فلا إشعارات ولا سبب ظاهر.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
