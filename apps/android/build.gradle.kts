// Top-level build file. Plugins declared here so subprojects can apply them
// without re-declaring versions.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.secrets.gradle) apply false
}
