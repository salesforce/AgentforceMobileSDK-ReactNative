package com.salesforce.android.reactagentforce

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Rect
import android.graphics.drawable.Drawable
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.salesforce.android.agentforcesdk.components.theme.AgentforceColorToken
import com.salesforce.android.agentforcesdk.components.theme.AgentforceDisplayNameType
import com.salesforce.android.agentforcesdk.components.theme.AgentforceIcon
import com.salesforce.android.agentforcesdk.components.theme.AgentforceIconType
import com.salesforce.android.agentforcesdk.components.theme.AgentforceThemeMode
import com.salesforce.android.agentforcesdk.components.theme.AgentforceThemeOverrides
import com.salesforce.android.agentforcesdk.components.theme.AgentforceTheming
import com.salesforce.android.agentforcesdk.components.theme.AgentforceTypography
import androidx.compose.ui.graphics.Color

internal object AppearanceConfiguration {
    fun theming(config: ReadableMap, context: Context): AgentforceTheming? {
        if (!config.hasKey("appearance") || config.getType("appearance") == ReadableType.Null) return null
        val raw = config.getMap("appearance") ?: throw IllegalArgumentException("appearance must be an object")
        val overrides = AgentforceThemeOverrides(
            lightColors = colors(raw.getMapOrNull("lightColors"), "lightColors"),
            darkColors = colors(raw.getMapOrNull("darkColors"), "darkColors"),
            displayNames = displayNames(raw.getMapOrNull("displayNames")),
            icons = icons(raw.getMapOrNull("icons"), context),
            themeMode = themeMode(raw.getStringOrNull("themeMode")),
            typography = typography(raw.getMapOrNull("typography"), context)
        )
        return AgentforceTheming.Overrides(overrides)
    }

    private fun colors(values: ReadableMap?, field: String): Map<AgentforceColorToken, Color> {
        if (values == null) return emptyMap()
        val result = mutableMapOf<AgentforceColorToken, Color>()
        val keys = values.keySetIterator()
        while (keys.hasNextKey()) {
            val key = keys.nextKey()
            val token = AgentforceColorToken.entries.firstOrNull { it.key == key }
                ?: throw IllegalArgumentException("Unsupported Android color token '$key'")
            val value = values.getString(key)
                ?: throw IllegalArgumentException("appearance.$field.$key must be a color string")
            result[token] = color(value, "appearance.$field.$key")
        }
        return result
    }

    private fun color(value: String, field: String): Color {
        val hex = value.trim()
        if (!Regex("^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$").matches(hex)) {
            throw IllegalArgumentException("$field must be #RRGGBB or #AARRGGBB")
        }
        val parsed = hex.drop(1).toLong(16)
        return if (hex.length == 7) Color(0xFF000000 or parsed) else Color(parsed)
    }

    private fun displayNames(values: ReadableMap?): Map<AgentforceDisplayNameType, String> {
        if (values == null) return emptyMap()
        val result = mutableMapOf<AgentforceDisplayNameType, String>()
        val keys = values.keySetIterator()
        while (keys.hasNextKey()) {
            val key = keys.nextKey()
            val type = AgentforceDisplayNameType.entries.firstOrNull { it.name.replaceFirstChar(Char::lowercase) == key }
                ?: throw IllegalArgumentException("Unsupported Android display-name token '$key'")
            val value = values.getString(key)
            if (value.isNullOrEmpty()) throw IllegalArgumentException("appearance.displayNames.$key must not be empty")
            result[type] = value
        }
        return result
    }

    private fun icons(values: ReadableMap?, context: Context): Map<AgentforceIconType, AgentforceIcon> {
        if (values == null) return emptyMap()
        val result = mutableMapOf<AgentforceIconType, AgentforceIcon>()
        val keys = values.keySetIterator()
        while (keys.hasNextKey()) {
            val key = keys.nextKey()
            val type = AgentforceIconType.entries.firstOrNull { it.name.replaceFirstChar(Char::lowercase) == key }
                ?: throw IllegalArgumentException("Unsupported Android icon token '$key'")
            val platform = values.getMap(key)?.getMap("android")
                ?: throw IllegalArgumentException("appearance.icons.$key requires android.light")
            val light = platform.getString("light")
                ?: throw IllegalArgumentException("appearance.icons.$key requires android.light")
            val lightPainter = painter(light, context, "appearance.icons.$key.android.light")
            val darkPainter = platform.getString("dark")?.let {
                painter(it, context, "appearance.icons.$key.android.dark")
            }
            result[type] = AgentforceIcon(lightPainter, darkPainter ?: lightPainter)
        }
        return result
    }

    private fun painter(resourceName: String, context: Context, field: String): BitmapPainter {
        val id = context.resources.getIdentifier(resourceName, "drawable", context.packageName)
        if (id == 0) throw IllegalArgumentException("Android drawable '$resourceName' for $field was not found")
        val bitmap = BitmapFactory.decodeResource(context.resources, id)
            ?: context.getDrawable(id)?.let(::drawableBitmap)
            ?: throw IllegalArgumentException("Android drawable '$resourceName' for $field could not be decoded")
        return BitmapPainter(bitmap.asImageBitmap())
    }

    /** Vector drawables cannot be decoded by BitmapFactory, so rasterize them for Compose. */
    internal fun drawableBitmap(drawable: Drawable): Bitmap {
        val previousBounds = Rect(drawable.bounds)
        val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 1
        val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 1
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also { bitmap ->
            try {
                drawable.setBounds(0, 0, width, height)
                drawable.draw(Canvas(bitmap))
            } finally {
                drawable.bounds = previousBounds
            }
        }
    }

    private fun themeMode(value: String?): AgentforceThemeMode? = when (value) {
        null -> null
        "system" -> AgentforceThemeMode.SYSTEM
        "light" -> AgentforceThemeMode.LIGHT
        "dark" -> AgentforceThemeMode.DARK
        else -> throw IllegalArgumentException("appearance.themeMode must be 'system', 'light', or 'dark'")
    }

    private fun typography(raw: ReadableMap?, context: Context): com.salesforce.android.sharedui.theme.Typography? {
        if (raw == null) return null
        val base = raw.getMapOrNull("fontFamily")?.let { family(it, context) }?.let {
            AgentforceTypography.Default.copyWithFontFamily(it)
        } ?: AgentforceTypography.Default
        val styles = raw.getMapOrNull("styles") ?: return base
        val overrides = mutableMapOf<String, TextStyle>()
        val keys = styles.keySetIterator()
        while (keys.hasNextKey()) {
            val name = keys.nextKey()
            val current = base[name] ?: throw IllegalArgumentException("Unsupported Android typography style '$name'")
            val rawStyle = styles.getMap(name) ?: throw IllegalArgumentException("appearance.typography.styles.$name must be an object")
            val size = rawStyle.getDoubleOrNull("size")?.also {
                if (!it.isFinite() || it <= 0 || it > 512) throw IllegalArgumentException("appearance.typography.styles.$name.size must be between 0 and 512")
            }?.toFloat()?.sp ?: current.fontSize
            val weight = rawStyle.getIntOrNull("weight")?.let { fontWeight(it) } ?: current.fontWeight
            val styleFamily = rawStyle.getMapOrNull("fontFamily")?.let { family(it, context) } ?: current.fontFamily
            overrides[name] = current.copy(fontSize = size, fontWeight = weight, fontFamily = styleFamily)
        }
        return base.mergeWith(overrides)
    }

    private fun family(raw: ReadableMap, context: Context): FontFamily {
        return when (raw.getString("type")) {
            "generic" -> when (raw.getString("family")) {
                "default" -> FontFamily.Default
                "sans-serif" -> FontFamily.SansSerif
                "serif" -> FontFamily.Serif
                "monospace" -> FontFamily.Monospace
                "cursive" -> FontFamily.Cursive
                else -> throw IllegalArgumentException("Unsupported generic font family")
            }
            "bundled" -> {
                val resources = raw.getMap("android")?.getMap("resources")
                    ?: throw IllegalArgumentException("Bundled Android font requires android.resources")
                val fonts = mutableListOf<Font>()
                val keys = resources.keySetIterator()
                while (keys.hasNextKey()) {
                    val weightKey = keys.nextKey()
                    val weight = fontWeight(weightKey.toIntOrNull() ?: throw IllegalArgumentException("Android font resource weight must be numeric"))
                    val name = resources.getString(weightKey)
                        ?: throw IllegalArgumentException("Android font resource name is required")
                    val id = context.resources.getIdentifier(name, "font", context.packageName)
                    if (id == 0) throw IllegalArgumentException("Android font resource '$name' was not found")
                    fonts += Font(id, weight)
                }
                if (fonts.isEmpty()) throw IllegalArgumentException("Bundled Android font requires at least one resource")
                FontFamily(*fonts.toTypedArray())
            }
            else -> throw IllegalArgumentException("appearance typography font family is invalid")
        }
    }

    private fun fontWeight(value: Int): FontWeight = when (value) {
        100, 200, 300, 400, 500, 600, 700, 800, 900 -> FontWeight(value)
        else -> throw IllegalArgumentException("Typography weight must be one of 100 through 900 in increments of 100")
    }

    private fun ReadableMap.getMapOrNull(key: String): ReadableMap? = if (hasKey(key) && getType(key) != ReadableType.Null) getMap(key) else null
    private fun ReadableMap.getStringOrNull(key: String): String? = if (hasKey(key) && getType(key) != ReadableType.Null) getString(key) else null
    private fun ReadableMap.getDoubleOrNull(key: String): Double? = if (hasKey(key) && getType(key) != ReadableType.Null) getDouble(key) else null
    private fun ReadableMap.getIntOrNull(key: String): Int? = getDoubleOrNull(key)?.toInt()
}
