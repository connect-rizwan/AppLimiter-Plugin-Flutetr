package io.github.connectrizwan.app_limiter

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.ByteArrayOutputStream

/** Lists apps that have a launcher icon. Slow with icons; call off the main thread. */
internal object InstalledApps {
    fun query(
        context: Context,
        includeIcons: Boolean,
        includeSystemApps: Boolean,
        iconSize: Int,
    ): List<Map<String, Any?>> {
        val packageManager = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities: List<ResolveInfo> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(launcherIntent, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(launcherIntent, 0)
        }

        return activities
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != context.packageName }
            .filter { includeSystemApps || !isSystemApp(it) }
            .map { info ->
                mapOf(
                    "packageName" to info.packageName,
                    "name" to info.loadLabel(packageManager).toString(),
                    "isSystemApp" to isSystemApp(info),
                    "category" to category(info),
                    "icon" to if (includeIcons) iconPng(info.loadIcon(packageManager), iconSize) else null,
                )
            }
            .sortedBy { (it["name"] as String).lowercase() }
    }

    private fun isSystemApp(info: ApplicationInfo): Boolean {
        return info.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    }

    private fun category(info: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "undefined"
        return categoryName(info.category)
    }

    /** Maps ApplicationInfo.CATEGORY_* values to the Dart AppCategory names. */
    fun categoryName(category: Int): String {
        return when (category) {
            0 -> "game"
            1 -> "audio"
            2 -> "video"
            3 -> "image"
            4 -> "social"
            5 -> "news"
            6 -> "maps"
            7 -> "productivity"
            8 -> "accessibility"
            else -> "undefined"
        }
    }

    private fun iconPng(drawable: Drawable, size: Int): ByteArray? {
        return try {
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                bitmap.recycle()
                stream.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
    }
}
