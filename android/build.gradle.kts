allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir("../build"))

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}