/*
 * Copyright (c) 2020-present, salesforce.com, inc.
 * All rights reserved.
 * Redistribution and use of this software in source and binary forms, with or
 * without modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * - Neither the name of salesforce.com, inc. nor the names of its contributors
 * may be used to endorse or promote products derived from this software without
 * specific prior written permission of salesforce.com, inc.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
package com.salesforce.android.reactagentforce

import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.salesforce.android.mobile.interfaces.permission.Permissions
import kotlinx.coroutines.CompletableDeferred
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

class AgentforceClientPermissions(private var activity: Activity) : Permissions {
    var requestCode: AtomicInteger = AtomicInteger(0)

    companion object {
        private val pendingRequests = ConcurrentHashMap<Int, CompletableDeferred<Boolean>>()

        /**
         * This method should be called from the activity's onRequestPermissionsResult method.
         * Exposed as static for Java callers (e.g. MainActivity).
         */
        @JvmStatic
        fun handlePermissionResult(requestCode: Int, permissions: Array<out String?>, grantResults: IntArray) {
            val deferred = pendingRequests.remove(requestCode)
            if (deferred != null) {
                val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                deferred.complete(allGranted)
            }
        }
    }

    override fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
    }

    override suspend fun requestPermissions(permissions: Array<String>, reason: String?): Boolean {
        // Check if all permissions are already granted
        val allGranted = permissions.all { hasPermission(it) }
        if (allGranted) {
            return true
        }

        // Generate a unique request code
        val currentRequestCode = requestCode.incrementAndGet()

        // Create a deferred result to handle async permission request
        val deferred = CompletableDeferred<Boolean>()
        pendingRequests[currentRequestCode] = deferred

        // Launch the permission request using the traditional approach
        ActivityCompat.requestPermissions(activity, permissions, currentRequestCode)

        // Wait for the result and return it
        return deferred.await()
    }

    override fun shouldShowRequestPermissionRationale(permission: String): Boolean {
        return ActivityCompat.shouldShowRequestPermissionRationale(activity, permission)
    }
}
