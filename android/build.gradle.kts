buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Updated to 8.2.2 for robust support of Java 17 and SDK 35/36
        classpath("com.android.tools.build:gradle:8.2.2")
        // Kotlin 1.9.24 for maximum stability with AGP 8.2+
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.value(rootProject.layout.buildDirectory.dir("../../build").get())

subprojects {
    project.layout.buildDirectory.value(rootProject.layout.buildDirectory.get().dir(project.name))
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
