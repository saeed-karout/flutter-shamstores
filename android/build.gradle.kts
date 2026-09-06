allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Disable lint to save memory
subprojects {
    tasks.configureEach {
        if (name.contains("lint", ignoreCase = true)) {
            enabled = false
        }
    }
}

// ملاحظة: كان هنا `resolutionStrategy` يفرض كل حزم `org.jetbrains.kotlin`
// على 1.9.25، مع `-Xskip-metadata-version-check` لإسكات ما ينتج عنه. وهو
// التفافٌ على تعارضٍ قديم، صار هو التعارض بعد رفع KGP إلى 2.1: يبقى
// `kotlin-build-tools-impl` على 1.9.25 بينما الإضافة 2.1، فيفشل البناء
// بـ«must have version aligned with the version of KGP».
//
// الحلّ أن تتوافق النسخ لا أن يُخفى اختلافها.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
