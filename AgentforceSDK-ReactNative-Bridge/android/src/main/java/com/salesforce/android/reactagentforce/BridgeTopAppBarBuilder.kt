/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.salesforce.android.agentforcesdk.components.models.ScreenType
import com.salesforce.android.agentforcesdk.components.models.TopAppBarBuilder
import com.salesforce.android.agentforcesdk.components.models.TopAppBarState
import com.salesforce.android.agentforcesdk.components.theme.LocalAgentforceTheme

/**
 * Custom [TopAppBarBuilder] that overrides the conversation header title with a
 * client-supplied Employee Agent label.
 *
 * Background: the Android SDK resolves its default header title as
 * `selectedAgent?.label ?: alternateTitle ?: default` — the server-provided agent
 * label always wins, and there is no config field that lets a client value take
 * precedence. The SDK's only top-bar customization hook is [TopAppBarBuilder], and
 * it is all-or-nothing per screen: either call `defaultContent()` (server title) or
 * render a fully custom bar. To honor "client label wins" while keeping the SDK's
 * default look and controls, this builder renders a bar from [TopAppBarState] that
 * is visually equivalent to the SDK default ([AgentforceTitleRow]) but titled with
 * the client label.
 *
 * Mirrors the iOS bridge's `BridgeNavigationBarBuilder`.
 *
 * Behavior:
 * - CHAT_FEED with a non-empty [agentLabel] -> custom bar titled with the label.
 * - Otherwise -> `defaultContent()` so the SDK falls back to the server label.
 *
 * Note: this is only installed when a non-empty label is supplied (see
 * [AgentforceModule.configureEmployeeAgent]); with no label the SDK's
 * `DefaultTopAppBarBuilder` is used instead.
 */
class BridgeTopAppBarBuilder(private val agentLabel: String) : TopAppBarBuilder {

    @Composable
    override fun TopAppBar(state: TopAppBarState, defaultContent: @Composable () -> Unit) {
        if (state.screenType == ScreenType.CHAT_FEED && agentLabel.isNotBlank()) {
            ClientLabelTopBar(label = agentLabel, state = state)
        } else {
            // Forms, onboarding, loading, error — keep SDK defaults.
            defaultContent()
        }
    }
}

/**
 * Renders a top bar matching the SDK's default chat header (close icon, centered
 * title with optional agent selector, overflow menu), but using the client label as
 * the title. Built entirely from public component models + theme so it stays
 * decoupled from SDK internals.
 */
@Composable
private fun ClientLabelTopBar(label: String, state: TopAppBarState) {
    val colors = LocalAgentforceTheme.current.colors()
    val typography = LocalAgentforceTheme.current.typography()

    var showAgentMenu by remember { mutableStateOf(false) }
    var showActionMenu by remember { mutableStateOf(false) }

    val showAgentSelector = state.agents.size > 1

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .background(colors.chatHeaderBackground)
                .padding(horizontal = 16.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            // Close button (matches SDK default; bridge previously used a back arrow).
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = "Close",
                tint = colors.onSurface3,
                modifier = Modifier
                    .size(20.dp)
                    .clickable(
                        onClick = state.onClose,
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    )
            )

            // Title + optional agent selector.
            Box(modifier = Modifier.weight(1f, fill = false)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .then(
                            if (showAgentSelector) {
                                Modifier.clickable(
                                    onClick = { showAgentMenu = true },
                                    interactionSource = remember { MutableInteractionSource() },
                                    indication = null
                                )
                            } else {
                                Modifier
                            }
                        )
                        .semantics(mergeDescendants = true) { heading() }
                ) {
                    Text(
                        text = label,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = typography.titlesFontScale3Regular.copy(color = colors.onSurface1),
                        modifier = Modifier.weight(1f, fill = false)
                    )
                    if (showAgentSelector) {
                        Icon(
                            imageVector = Icons.Filled.KeyboardArrowDown,
                            contentDescription = "Select agent",
                            tint = colors.onSurface3,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }

                DropdownMenu(
                    expanded = showAgentMenu,
                    onDismissRequest = { showAgentMenu = false }
                ) {
                    state.agents.forEach { agent ->
                        DropdownMenuItem(
                            onClick = {
                                state.onAgentSelect(agent.id)
                                showAgentMenu = false
                            },
                            leadingIcon = if (agent.id == state.selectedAgentId) {
                                {
                                    Icon(
                                        imageVector = Icons.Filled.Check,
                                        contentDescription = null,
                                        tint = colors.accent1,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            } else {
                                null
                            },
                            text = {
                                Text(
                                    text = agent.displayName,
                                    style = typography.bodyFontScale1Regular.copy(color = colors.onSurface1)
                                )
                            }
                        )
                    }
                }
            }

            // Overflow / more-menu — delegates to the SDK's own bottom sheet.
            Box {
                IconButton(
                    onClick = {
                        // Surface server-provided dynamic options inline; otherwise open
                        // the SDK more menu directly.
                        if (state.dynamicMenuOptions.isNotEmpty()) {
                            showActionMenu = true
                        } else {
                            state.onShowMoreMenu()
                        }
                    },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        imageVector = Icons.Filled.MoreVert,
                        contentDescription = "More options",
                        tint = colors.onSurface3,
                        modifier = Modifier.size(20.dp)
                    )
                }

                DropdownMenu(
                    expanded = showActionMenu,
                    onDismissRequest = { showActionMenu = false }
                ) {
                    state.dynamicMenuOptions.forEach { option ->
                        DropdownMenuItem(
                            onClick = {
                                showActionMenu = false
                                state.onDynamicMenuOptionClick(option)
                            },
                            text = {
                                Text(
                                    text = option.title,
                                    style = typography.bodyFontScale1Regular.copy(color = colors.onSurface1)
                                )
                            }
                        )
                    }
                    if (state.dynamicMenuOptions.isNotEmpty()) {
                        HorizontalDivider(color = colors.border1)
                    }
                    DropdownMenuItem(
                        onClick = {
                            showActionMenu = false
                            state.onShowMoreMenu()
                        },
                        text = {
                            Text(
                                text = "More Options",
                                style = typography.bodyFontScale1Regular.copy(color = colors.onSurface1)
                            )
                        }
                    )
                }
            }
        }

        HorizontalDivider(color = colors.border1)
    }
}
