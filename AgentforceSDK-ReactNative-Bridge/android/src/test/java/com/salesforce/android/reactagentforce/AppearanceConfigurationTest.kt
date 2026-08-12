package com.salesforce.android.reactagentforce

import android.content.Context
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableMapKeySetIterator
import com.facebook.react.bridge.ReadableType
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class AppearanceConfigurationTest {

    @Test
    fun `returns null when appearance is absent`() {
        val config = readableMap()

        assertNull(AppearanceConfiguration.theming(config, mockk()))
    }

    @Test
    fun `maps representative color display name theme mode and typography overrides`() {
        val appearance = readableMap(
            maps = mapOf(
                "lightColors" to readableMap(strings = mapOf("chatBackground" to "#FFFFFF")),
                "darkColors" to readableMap(strings = mapOf("chatBackground" to "#80181818")),
                "displayNames" to readableMap(strings = mapOf("inputTextPlaceholder" to "Ask Acme")),
                "typography" to readableMap(
                    maps = mapOf(
                        "fontFamily" to readableMap(strings = mapOf("type" to "generic", "family" to "serif")),
                        "styles" to readableMap(
                            maps = mapOf(
                                "bodyFontScale1Regular" to readableMap(
                                    doubles = mapOf("size" to 14.0, "weight" to 400.0),
                                ),
                            ),
                        ),
                    ),
                ),
            ),
            strings = mapOf("themeMode" to "dark"),
        )

        val result = AppearanceConfiguration.theming(
            readableMap(maps = mapOf("appearance" to appearance)),
            mockk<Context>(relaxed = true),
        )

        assertEquals("Overrides", result!!::class.simpleName)
    }

    @Test
    fun `rejects invalid color values and tokens`() {
        assertInvalidAppearance(
            readableMap(maps = mapOf("lightColors" to readableMap(strings = mapOf("chatBackground" to "blue")))),
            "appearance.lightColors.chatBackground must be #RRGGBB or #AARRGGBB",
        )
        assertInvalidAppearance(
            readableMap(maps = mapOf("lightColors" to readableMap(strings = mapOf("unknown" to "#FFFFFF")))),
            "Unsupported Android color token 'unknown'",
        )
    }

    @Test
    fun `rejects invalid theme mode`() {
        assertInvalidAppearance(
            readableMap(strings = mapOf("themeMode" to "auto")),
            "appearance.themeMode must be 'system', 'light', or 'dark'",
        )
    }

    @Test
    fun `rejects unsupported and empty display names`() {
        assertInvalidAppearance(
            readableMap(maps = mapOf("displayNames" to readableMap(strings = mapOf("unknown" to "Name")))),
            "Unsupported Android display-name token 'unknown'",
        )
        assertInvalidAppearance(
            readableMap(maps = mapOf("displayNames" to readableMap(strings = mapOf("inputTextPlaceholder" to "")))),
            "appearance.displayNames.inputTextPlaceholder must not be empty",
        )
    }

    @Test
    fun `rejects invalid typography family style size and weight`() {
        assertInvalidAppearance(
            readableMap(maps = mapOf("typography" to readableMap(
                maps = mapOf("fontFamily" to readableMap(strings = mapOf("type" to "generic", "family" to "comic-sans"))),
            ))),
            "Unsupported generic font family",
        )
        assertInvalidAppearance(
            readableMap(maps = mapOf("typography" to typographyStyle("unknown", doubles = mapOf("size" to 14.0)))),
            "Unsupported Android typography style 'unknown'",
        )
        assertInvalidAppearance(
            readableMap(maps = mapOf("typography" to typographyStyle("bodyFontScale1Regular", doubles = mapOf("size" to 0.0)))),
            "appearance.typography.styles.bodyFontScale1Regular.size must be between 0 and 512",
        )
        assertInvalidAppearance(
            readableMap(maps = mapOf("typography" to typographyStyle("bodyFontScale1Regular", doubles = mapOf("weight" to 450.0)))),
            "Typography weight must be one of 100 through 900 in increments of 100",
        )
    }

    @Test
    fun `rejects icons without Android light resources`() {
        assertInvalidAppearance(
            readableMap(maps = mapOf("icons" to readableMap(maps = mapOf("aiAgent" to readableMap())))),
            "appearance.icons.aiAgent requires android.light",
        )
    }

    @Test
    fun `caps oversized drawable dimensions during rasterization`() {
        val (width, height) = AppearanceConfiguration.drawableSize(4096, 2048)

        assertEquals(1024, width)
        assertEquals(512, height)
    }

    private fun typographyStyle(name: String, doubles: Map<String, Double>): ReadableMap = readableMap(
        maps = mapOf("styles" to readableMap(maps = mapOf(name to readableMap(doubles = doubles)))),
    )

    private fun assertInvalidAppearance(appearance: ReadableMap, message: String) {
        val exception = assertThrows(IllegalArgumentException::class.java) {
            AppearanceConfiguration.theming(
                readableMap(maps = mapOf("appearance" to appearance)),
                mockk<Context>(relaxed = true),
            )
        }
        assertEquals(message, exception.message)
    }

    private fun readableMap(
        strings: Map<String, String?> = emptyMap(),
        doubles: Map<String, Double> = emptyMap(),
        maps: Map<String, ReadableMap?> = emptyMap(),
    ): ReadableMap {
        val keys = (strings.keys + doubles.keys + maps.keys).toList()
        return mockk<ReadableMap>(relaxed = true) {
            every { hasKey(any()) } answers { keys.contains(firstArg<String>()) }
            every { getType(any()) } answers {
                when (firstArg<String>()) {
                    in strings -> if (strings[firstArg<String>()] == null) ReadableType.Null else ReadableType.String
                    in doubles -> ReadableType.Number
                    in maps -> if (maps[firstArg<String>()] == null) ReadableType.Null else ReadableType.Map
                    else -> ReadableType.Null
                }
            }
            every { getString(any()) } answers { strings[firstArg<String>()] }
            every { getDouble(any()) } answers { doubles[firstArg<String>()] ?: 0.0 }
            every { getMap(any()) } answers { maps[firstArg<String>()] }
            every { keySetIterator() } answers {
                val iterator = mockk<ReadableMapKeySetIterator>()
                var index = 0
                every { iterator.hasNextKey() } answers { index < keys.size }
                every { iterator.nextKey() } answers { keys[index++] }
                iterator
            }
        }
    }
}
