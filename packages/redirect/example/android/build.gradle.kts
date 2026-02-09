allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Resolve to an absolute File to ensure a proper path on the project's drive.
// See: https://github.com/flutter/flutter/issues/105395
// Use "../build" so the output lands at example/build/ — Flutter CLI expects
// the APK at <project_dir>/build/ (which is the example directory), not the
// parent plugin directory.
val newBuildDir: File = rootProject.projectDir.resolve("../build").canonicalFile

rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    // Only redirect buildDir for subprojects on the same drive root.
    // Plugins from the Pub cache on a different drive keep their default
    // buildDir (under their own projectDir), avoiding the cross-drive
    // File.toRelativeString() failure in AGP.
    val projectRoot = project.projectDir.toPath().root
    val buildRoot = newBuildDir.toPath().root
    if (projectRoot == buildRoot) {
        project.layout.buildDirectory.set(File(newBuildDir, project.name))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}