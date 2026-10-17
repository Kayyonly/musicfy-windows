plugins {
    application
    java
    id("org.openjfx.javafxplugin") version "0.1.0"
}

group = "musicfy.windows.poc"
version = "0.1.0"

repositories {
    mavenCentral()
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

javafx {
    version = "21.0.12"
    modules = listOf("javafx.controls", "javafx.media")
}

dependencies {
    // Stable vlcj 4.x binding; requires a compatible VLC 3.x LibVLC runtime at runtime.
    implementation("uk.co.caprica:vlcj:4.12.1")
}

application {
    mainClass.set("musicfy.poc.PlaybackPocApp")
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
    options.release.set(21)
}
