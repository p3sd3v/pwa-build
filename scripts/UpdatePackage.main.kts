#!/usr/bin/env kotlin

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.nio.file.Paths

// Configuration
// Detect if running from root or scripts dir
val currentDir = File(".").absoluteFile
val projectRoot = if (currentDir.name == "scripts") currentDir.parentFile else currentDir
val androidAppDir = File(projectRoot, "android/app/src/main")
val kotlinDir = File(androidAppDir, "kotlin")
val javaDir = File(androidAppDir, "java")

// Get Package Name from Env
val packageName = System.getenv("PACKAGENAME")

if (packageName.isNullOrEmpty()) {
    println("❌ PACKAGENAME environment variable is not set.")
    System.exit(1)
}

println("🚀 Starting Package Migration to: $packageName")

// Function to find MainActivity
fun findMainActivity(baseDir: File): File? {
    return baseDir.walkTopDown().find { it.name == "MainActivity.kt" || it.name == "MainActivity.java" }
}

// Function to move and update file
fun migrateMainActivity(baseDir: File, newPackage: String) {
    val mainActivity = findMainActivity(baseDir)
    if (mainActivity == null) {
        println("⚠️ MainActivity not found in ${baseDir.path}")
        return
    }

    val currentPackagePath = mainActivity.parentFile.absolutePath
    val newPackagePath = File(baseDir, newPackage.replace('.', '/')).absolutePath

    if (currentPackagePath == newPackagePath) {
        println("✅ MainActivity is already in the correct path: $newPackagePath")
        return
    }

    println("📦 Moving MainActivity form $currentPackagePath to $newPackagePath")

    // Create new directory structure
    File(newPackagePath).mkdirs()

    // Move file
    val newFile = File(newPackagePath, mainActivity.name)
    Files.move(mainActivity.toPath(), newFile.toPath(), StandardCopyOption.REPLACE_EXISTING)

    // Update package declaration
    val content = newFile.readText()
    val packageRegex = Regex("^package\\s+[\\w\\.]+", RegexOption.MULTILINE)
    val newContent = packageRegex.replace(content, "package $newPackage")
    newFile.writeText(newContent)

    println("✅ Updated package declaration in ${newFile.name}")

    // Clean up empty directories
    deleteEmptyDirectories(mainActivity.parentFile, baseDir)
}

fun deleteEmptyDirectories(directory: File, root: File) {
    if (!directory.exists()) return
    var current = directory
    while (current.absolutePath != root.absolutePath && current.exists() && (current.listFiles()?.isEmpty() == true)) {
        println("🗑️ Deleting empty directory: ${current.path}")
        current.delete()
        current = current.parentFile
    }
}

// Execute
if (kotlinDir.exists()) {
    migrateMainActivity(kotlinDir, packageName)
}

if (javaDir.exists()) {
    migrateMainActivity(javaDir, packageName)
}

println("🎉 Migration completed successfully!")
