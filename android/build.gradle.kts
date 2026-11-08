allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Force every plugin to compile against Android SDK 36 (fixes "compiled against android-34").
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val dsl = Class.forName(
                    "com.android.build.api.dsl.CommonExtension",
                    true,
                    androidExt.javaClass.classLoader
                )
                dsl.getMethod("setCompileSdk", Int::class.javaObjectType).invoke(androidExt, 36)
                println("Vaulta: compileSdk set to 36 for ${project.name}")
            } catch (e: Exception) {
                println("Vaulta: could not set compileSdk for ${project.name}: $e")
            }
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}