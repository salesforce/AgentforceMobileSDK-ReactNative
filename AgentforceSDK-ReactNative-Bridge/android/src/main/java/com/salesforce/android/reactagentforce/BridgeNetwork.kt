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

    override suspend fun perform(request: NetworkRequest): NetworkResponse {
        return suspendCoroutine { continuation ->
            restClient.sendAsync(
                request.toRestRequest(),
                object : RestClient.AsyncRequestCallback {
                    override fun onSuccess(req: RestRequest?, resp: RestResponse?) {
                        continuation.resume(processResponse(resp, request))
                    }

                    override fun onError(exception: Exception?) {
                        // Return unknown status code on error - preserves error type information
                        // SDK will handle gracefully regardless of status code
                        continuation.resume(NetworkResponse(request, NetworkResponse.STATUS_CODE_UNKNOWN))
                    }
                }
            )
        }
    }

    private fun processResponse(resp: RestResponse?, request: NetworkRequest): NetworkResponse {
        return NetworkResponse(
            request,
            resp?.statusCode ?: NetworkResponse.STATUS_CODE_UNKNOWN,
            resp?.allHeaders ?: emptyMap(),
            resp?.asBytes()
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

        // Create RestRequest - use body constructor if body exists, else query params constructor
        val restRequest = if (body != null && body!!.isNotEmpty()) {
            val mediaType = contentType?.toMediaType()
            val requestBody = body!!.toRequestBody(mediaType)
            RestRequest(restMethod, path, requestBody)
        } else {
            val queryMap = queryParams.mapValues { it.value.toString() }.toMutableMap()
            RestRequest(restMethod, path, queryMap)
        }

        // Add custom headers
        additionalHttpHeaders.forEach { (key, value) ->
            restRequest.additionalHttpHeaders[key] = value
        }

        return restRequest
    }
}
