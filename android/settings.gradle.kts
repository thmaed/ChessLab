pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}

rootProject.name = "chesslab-android"

// :chesskit est du Kotlin JVM PUR — ses tests tournent sans émulateur, et
// c'est la boucle de travail principale du portage.
include(":chesskit")
include(":engine")
include(":app")
