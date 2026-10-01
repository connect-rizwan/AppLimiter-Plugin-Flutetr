package io.github.connectrizwan.app_limiter

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import java.io.File

/** Developer-provided look of the block screen. Null fields keep the default. */
internal data class BlockScreenConfig(
    val title: String? = null,
    val message: String? = null,
    val footer: String? = null,
    val backgroundColor: Int? = null,
    val textColor: Int? = null,
    val buttonLabel: String? = null,
    val buttonAction: String = ACTION_CLOSE_APP,
    val showIcon: Boolean = true,
) {
    companion object {
        const val ACTION_CLOSE_APP = "closeApp"
        const val ACTION_OPEN_HOST_APP = "openHostApp"

        fun fromMap(map: Map<String, Any?>): BlockScreenConfig {
            fun string(key: String) = (map[key] as? String)?.takeIf { it.isNotBlank() }
            fun color(key: String) = (map[key] as? Number)?.toInt()
            val action = map["buttonAction"] as? String
            return BlockScreenConfig(
                title = string("title"),
                message = string("message"),
                footer = string("footer"),
                backgroundColor = color("backgroundColor"),
                textColor = color("textColor"),
                buttonLabel = string("buttonLabel"),
                buttonAction = if (action == ACTION_OPEN_HOST_APP) ACTION_OPEN_HOST_APP else ACTION_CLOSE_APP,
                showIcon = map["showIcon"] as? Boolean ?: true,
            )
        }
    }
}

/** Persists the block screen and notification configuration. */
internal class BlockScreenStore(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val notificationPrefs =
        appContext.getSharedPreferences(NOTIFICATION_PREFS_NAME, Context.MODE_PRIVATE)
    private val iconFile = File(appContext.filesDir, ICON_FILE)

    fun load(): BlockScreenConfig {
        return BlockScreenConfig(
            title = prefs.getString("title", null),
            message = prefs.getString("message", null),
            footer = prefs.getString("footer", null),
            backgroundColor = if (prefs.contains("backgroundColor")) prefs.getInt("backgroundColor", 0) else null,
            textColor = if (prefs.contains("textColor")) prefs.getInt("textColor", 0) else null,
            buttonLabel = prefs.getString("buttonLabel", null),
            buttonAction = prefs.getString("buttonAction", null) ?: BlockScreenConfig.ACTION_CLOSE_APP,
            showIcon = prefs.getBoolean("showIcon", true),
        )
    }

    fun save(config: BlockScreenConfig, icon: ByteArray?) {
        prefs.edit().apply {
            clear()
            config.title?.let { putString("title", it) }
            config.message?.let { putString("message", it) }
            config.footer?.let { putString("footer", it) }
            config.backgroundColor?.let { putInt("backgroundColor", it) }
            config.textColor?.let { putInt("textColor", it) }
            config.buttonLabel?.let { putString("buttonLabel", it) }
            putString("buttonAction", config.buttonAction)
            putBoolean("showIcon", config.showIcon)
        }.apply()

        if (icon != null) iconFile.writeBytes(icon) else iconFile.delete()
    }

    fun loadIcon(): ByteArray? = if (iconFile.exists()) iconFile.readBytes() else null

    var notificationTitle: String?
        get() = notificationPrefs.getString(KEY_NOTIFICATION_TITLE, null)
        set(value) = notificationPrefs.edit().putString(KEY_NOTIFICATION_TITLE, value).apply()

    var notificationText: String?
        get() = notificationPrefs.getString(KEY_NOTIFICATION_TEXT, null)
        set(value) = notificationPrefs.edit().putString(KEY_NOTIFICATION_TEXT, value).apply()

    companion object {
        private const val PREFS_NAME = "app_limiter_block_screen"
        private const val NOTIFICATION_PREFS_NAME = "app_limiter_notification"
        private const val ICON_FILE = "app_limiter_block_screen_icon.png"
        private const val KEY_NOTIFICATION_TITLE = "notification_title"
        private const val KEY_NOTIFICATION_TEXT = "notification_text"
    }
}

/** Applies [config] to an inflated `block_overlay` view. */
internal object BlockScreen {
    fun apply(
        view: View,
        config: BlockScreenConfig,
        icon: ByteArray?,
        hostAppLabel: String,
        onButtonClick: () -> Unit,
    ) {
        // Views are nullable: a host app may override `block_overlay` with its
        // own layout, which is then shown as-is.
        val iconView: ImageView? = view.findViewById(R.id.block_icon)
        val title: TextView? = view.findViewById(R.id.block_title)
        val message: TextView? = view.findViewById(R.id.block_message)
        val detail: TextView? = view.findViewById(R.id.block_detail)
        val footer: TextView? = view.findViewById(R.id.block_footer)
        val button: Button? = view.findViewById(R.id.block_button)

        config.title?.let { title?.text = it }
        config.message?.let {
            message?.text = it
            detail?.visibility = View.GONE
        }
        footer?.text = config.footer ?: hostAppLabel

        config.backgroundColor?.let { view.setBackgroundColor(it) }
        config.textColor?.let { color ->
            listOfNotNull(title, message, detail, footer).forEach { it.setTextColor(color) }
            iconView?.setColorFilter(color)
        }

        val bitmap = icon?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
        if (bitmap != null && iconView != null) {
            iconView.clearColorFilter()
            iconView.imageTintList = null
            iconView.setImageBitmap(bitmap)
        }
        iconView?.visibility = if (config.showIcon) View.VISIBLE else View.GONE

        if (button != null) {
            if (config.buttonLabel != null) {
                button.text = config.buttonLabel
                button.visibility = View.VISIBLE
                button.setOnClickListener { onButtonClick() }
            } else {
                button.visibility = View.GONE
            }
        }
    }

    fun buttonIntent(context: Context, config: BlockScreenConfig): Intent {
        val hostApp = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val intent = if (config.buttonAction == BlockScreenConfig.ACTION_OPEN_HOST_APP && hostApp != null) {
            hostApp
        } else {
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        }
        return intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}
