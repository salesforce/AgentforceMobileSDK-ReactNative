/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Helpers for synthesizing navigation pageReferences forwarded to React Native JS.
 */
package com.salesforce.android.reactagentforce

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Builds a `standard__recordPage` pageReference JSON string for a record.
 *
 * The Android SDK's `Record` destination leaves `pageReference` null on a tapped record — its
 * navigation call sites use the short `Record(id, type)` constructor and the Android
 * SalesforceMobileInterfaces `Record` (unlike iOS) does not self-populate a pageReference. The
 * iOS SDK's `Record` initializer produces `{recordId, actionName: "view", objectApiName}`, so
 * JS consumers of `onNavigationRequest` see a `pageReference` on iOS but not Android
 * (W-23294974). This helper synthesizes the same shape so the bridge can emit a consistent
 * payload cross-platform.
 *
 * This is a temporary bridge-layer workaround. The durable fix is for the Android
 * SalesforceMobileInterfaces `Record` type to self-derive its pageReference like iOS; once that
 * ships, callers here will receive a non-null `Record.pageReference` and this synthesis becomes
 * a no-op fallback.
 *
 * kotlinx.serialization (not `org.json`) is used deliberately so the logic is pure-JVM and
 * unit-testable — the bridge test module sets `unitTests.returnDefaultValues = true`, which stubs
 * out Android's `org.json.JSONObject`.
 *
 * @param recordId the record id (18-char entity id)
 * @param objectType the object API name, if known; omitted from `attributes` when null/blank
 * @return the serialized `standard__recordPage` pageReference
 */
internal fun recordPageReference(recordId: String, objectType: String?): String {
    val attributes = buildMap {
        put(RECORD_ID_KEY, recordId)
        put(ACTION_NAME_KEY, VIEW_ACTION)
        if (!objectType.isNullOrBlank()) {
            put(OBJECT_API_NAME_KEY, objectType)
        }
    }
    return Json.encodeToString(
        NavigationPageReferencePayload(type = STANDARD_RECORD_PAGE, attributes = attributes)
    )
}

@Serializable
private data class NavigationPageReferencePayload(
    val type: String,
    val attributes: Map<String, String>,
)

private const val STANDARD_RECORD_PAGE = "standard__recordPage"
private const val RECORD_ID_KEY = "recordId"
private const val OBJECT_API_NAME_KEY = "objectApiName"
private const val ACTION_NAME_KEY = "actionName"
private const val VIEW_ACTION = "view"
