/*
 * Copyright (c) 2024-present, salesforce.com, inc.
 * All rights reserved.
 */
package com.salesforce.android.reactagentforce

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.ViewModelProvider
import com.salesforce.android.agentforcesdkimpl.AgentforceClient
import com.salesforce.android.agentforcesdkimpl.AgentforceConversation
import com.salesforce.android.reactagentforce.models.AgentMode

/**
 * Activity that displays the Agentforce conversation UI.
 * Supports both Service Agent and Employee Agent modes.
 * Uses Jetpack Compose to show the SDK-provided conversation interface.
 */
class AgentforceConversationActivity : ComponentActivity() {

    companion object {
        private const val TAG = "AgentforceConvActivity"
    }

    private var viewModel: ServiceAgentViewModel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "onCreate() called")

        // Try to get shared ViewModel for legacy Service Agent support
        try {
            viewModel = ViewModelProvider(
                this,
                ViewModelProvider.AndroidViewModelFactory.getInstance(application)
            )[ServiceAgentViewModel::class.java]
        } catch (e: Exception) {
            Log.w(TAG, "Could not get ViewModel: ${e.message}")
        }

        // Start conversation if not already started
        startConversationIfNeeded()

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    AgentforceConversationScreen(
                        viewModel = viewModel,
                        onClose = {
                            Log.d(TAG, "Closing conversation")
                            finish()
                        }
                    )
                }
            }
        }
    }
    
    private fun startConversationIfNeeded() {
        // Check unified path first (AgentforceClientHolder)
        if (AgentforceClientHolder.currentConversation != null) {
            Log.d(TAG, "Using existing conversation from AgentforceClientHolder")
            return
        }
        
        val client = AgentforceClientHolder.agentforceClient
        if (client != null) {
            val mode = AgentforceClientHolder.currentMode
            Log.d(TAG, "Starting conversation for mode: ${mode?.typeString ?: "unknown"}")
            // SDK exposes startAgentforceConversation(agentId: String? = null, sessionId: String? = null)
            // When agentId is null or blank, pass null so the SDK bootstraps and picks the first available agent (multi-agent path).
            // When agentId is set, the session starts with that agent.
            val agentIdParam = AgentforceClientHolder.agentId?.takeIf { it.isNotBlank() }

            // Check if multi-agent is enabled when agentId is null
            if (agentIdParam == null) {
                val prefs = getSharedPreferences("AgentforceFeatureFlags", MODE_PRIVATE)
                val multiAgentEnabled = prefs.getBoolean("enableMultiAgent", true)
                if (!multiAgentEnabled) {
                    Log.w(TAG, "WARNING: No agentId provided and multi-agent is disabled. Chat panel will likely fail.")
                }
                Log.d(TAG, "Starting conversation with agentId=null (multi-agent: $multiAgentEnabled)")
            }

            try {
                val conversation = client.startAgentforceConversation(agentId = agentIdParam)
                AgentforceClientHolder.setConversation(conversation)
                Log.d(TAG, "Conversation started and stored in AgentforceClientHolder")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start conversation", e)
            }
            return
        }
        
        // Fall back to legacy ViewModel path
        if (viewModel?.conversation?.value == null) {
            Log.d(TAG, "Starting conversation via legacy ViewModel")
            viewModel?.startConversation()
        }
    }
}

/**
 * Composable screen for displaying the Agentforce conversation.
 * Supports both Service Agent and Employee Agent modes.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AgentforceConversationScreen(
    viewModel: ServiceAgentViewModel?,
    onClose: () -> Unit
) {
    // Try unified path first
    val holderClient = AgentforceClientHolder.agentforceClient
    val holderConversation = AgentforceClientHolder.currentConversation
    
    // Fall back to legacy ViewModel
    val vmConversation = viewModel?.conversation?.collectAsState()?.value
    val vmClient = viewModel?.agentforceClient
    
    // Determine which client and conversation to use
    val client: AgentforceClient? = holderClient ?: vmClient
    val conversation: AgentforceConversation? = holderConversation ?: vmConversation
    
    // Determine title based on mode and agent label
    val title = when (val mode = AgentforceClientHolder.currentMode) {
        is AgentMode.Employee -> {
            // Use agentLabel if available, otherwise show generic title
            AgentforceClientHolder.agentLabel ?: "Employee Agent"
        }
        is AgentMode.Service -> {
            // For Service Agent, could show esDeveloperName if needed
            "Service Agent"
        }
        null -> "Agentforce"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        title,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFF0176D3), // Salesforce blue
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                ),
                windowInsets = WindowInsets(top = 50.dp, bottom = 0.dp),
                modifier = Modifier.heightIn(max = 95.dp)
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                conversation != null && client != null -> {
                    // Display the Agentforce Conversation Container with proper constraints
                    client.AgentforceConversationContainer(
                        conversation = conversation,
                        onClose = onClose
                    )
                }
                else -> {
                    // Loading state
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator()
                        Text(
                            text = "Initializing conversation...",
                            modifier = Modifier.padding(top = 16.dp)
                        )
                    }
                }
            }
        }
    }
}
