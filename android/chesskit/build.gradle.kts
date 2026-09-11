plugins { kotlin("jvm") }

dependencies { testImplementation(kotlin("test")) }

kotlin { jvmToolchain(21) }

tasks.test {
    useJUnitPlatform()
    testLogging { events("passed", "failed", "skipped"); showStandardStreams = true }
}
