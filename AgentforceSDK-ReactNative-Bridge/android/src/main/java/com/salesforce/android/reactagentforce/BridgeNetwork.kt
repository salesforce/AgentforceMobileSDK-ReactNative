/*
 * Copyright (c) 2026-present, salesforce.com, inc.
 * All rights reserved.
 *
 * Network implementation for Agentforce DataProvider
 * Uses Mobile SDK RestClient for authenticated API calls
 */
package com.salesforce.android.reactagentforce

import com.salesforce.android.mobile.interfaces.network.Network
import com.salesforce.android.mobile.interfaces.network.NetworkRequest
import com.salesforce.android.mobile.interfaces.network.NetworkResponse
import com.salesforce.androidsdk.rest.RestClient
import com.salesforce.androidsdk.rest.RestRequest
import com.salesforce.androidsdk.rest.RestResponse
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * Network implementation that bridges MobileExtensionSDK Network interface
 * to Mobile SDK RestClient for authenticated Salesforce API calls.
 */
class BridgeNetwork(private val restClient: RestClient) : Network {

    companion object {
        private const val TAG = "BridgeNetwork"
        // Cap how much of an error body we log so a large HTML/JSON error page
        // doesn't flood Logcat or the JS log channel.
        private const val MAX_ERROR_BODY = 2048
    }

    override suspend fun perform(request: NetworkRequest): NetworkResponse {
        return suspendCoroutine { continuation ->
            restClient.sendAsync(
                request.toRestRequest(),
                object : RestClient.AsyncRequestCallback {
                    override fun onSuccess(req: RestRequest?, resp: RestResponse?) {
                        continuation.resume(processResponse(resp, request))
                    }

                    override fun onError(exception: Exception?) {
                        // Surface the failure: every Agentforce API call (session-create,
                        // messaging, record fetch) flows through here, and an opaque
                        // STATUS_CODE_UNKNOWN is what the SDK renders as "Something went wrong".
                        BridgeDiagnostics.e(
                            TAG,
                            "Request FAILED (transport error) ${request.method} ${request.path}",
                            exception
                        )
                        // Return unknown status code on error - preserves error type information
                        // SDK will handle gracefully regardless of status code
                        continuation.resume(NetworkResponse(request, NetworkResponse.STATUS_CODE_UNKNOWN))
                    }
                }
            )
        }
    }

    private fun processResponse(resp: RestResponse?, request: NetworkRequest): NetworkResponse {
        val statusCode = resp?.statusCode ?: NetworkResponse.STATUS_CODE_UNKNOWN
        val bytes = resp?.asBytes()

        if (statusCode !in 200..299) {
            // Non-2xx: log status + a bounded slice of the response body. This is what
            // turns an opaque "Something went wrong" into an actionable cause
            // (403 = agent not assigned, 404 = wrong agentId, 401 = token/org mismatch).
            val body = bytes?.let { String(it, Charsets.UTF_8) }?.take(MAX_ERROR_BODY) ?: "<no body>"
            BridgeDiagnostics.e(
                TAG,
                "Request NON-2XX status=$statusCode ${request.method} ${request.path} | body: $body"
            )
        } else {
            BridgeDiagnostics.d(TAG, "Request OK status=$statusCode ${request.method} ${request.path}")
        }

        return NetworkResponse(
            request,
            statusCode,
            resp?.allHeaders ?: emptyMap(),
            bytes
        )
    }

    private fun NetworkRequest.toRestRequest(): RestRequest {
        val restMethod = when (method) {
            NetworkRequest.Method.GET -> RestRequest.RestMethod.GET
            NetworkRequest.Method.POST -> RestRequest.RestMethod.POST
            NetworkRequest.Method.PUT -> RestRequest.RestMethod.PUT
            NetworkRequest.Method.DELETE -> RestRequest.RestMethod.DELETE
            NetworkRequest.Method.PATCH -> RestRequest.RestMethod.PATCH
            NetworkRequest.Method.HEAD -> RestRequest.RestMethod.HEAD
        }

        // Append query params to the path as a query string.
        // RestRequest(RestMethod, String, Map) treats the Map as additionalHttpHeaders,
        // NOT query parameters, so we must encode them into the URL path ourselves.
        val fullPath = if (queryParams.isNotEmpty()) {
            val separator = if (path.contains("?")) "&" else "?"
            val queryString = queryParams.entries.joinToString("&") { (k, v) ->
                "${java.net.URLEncoder.encode(k, "UTF-8")}=${java.net.URLEncoder.encode(v.toString(), "UTF-8")}"
            }
            "$path$separator$queryString"
        } else {
            path
        }

        // Create RestRequest - use body constructor if body exists, else path-only constructor
        val restRequest = if (body != null && body!!.isNotEmpty()) {
            val mediaType = contentType?.toMediaType()
            val requestBody = body!!.toRequestBody(mediaType)
            RestRequest(restMethod, fullPath, requestBody)
        } else {
            RestRequest(restMethod, fullPath)
        }

        // Add custom headers
        additionalHttpHeaders.forEach { (key, value) ->
            restRequest.additionalHttpHeaders[key] = value
        }

        return restRequest
    }
}
