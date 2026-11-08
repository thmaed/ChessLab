plugins {
    id("com.android.application") version "9.5.1" apply false
    id("com.android.library") version "9.5.1" apply false
    id("org.jetbrains.kotlin.jvm") version "2.4.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.21" apply false
    id("com.google.devtools.ksp") version "2.3.13" apply false
    // La publication Google Play sans les mains — voir PUBLIER.md.
    id("com.github.triplet.play") version "4.1.1" apply false
}
