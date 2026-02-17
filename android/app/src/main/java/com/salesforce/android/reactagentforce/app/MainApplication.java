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
package com.salesforce.android.reactagentforce.app;

import android.app.Application;

import com.facebook.react.PackageList;
import com.facebook.react.ReactApplication;
import com.facebook.react.ReactNativeHost;
import com.facebook.react.ReactPackage;
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint;
import com.facebook.react.defaults.DefaultReactNativeHost;
import com.facebook.soloader.SoLoader;
import com.salesforce.androidsdk.app.SalesforceSDKManager;

import java.util.List;

/**
 * Application class for Agentforce sample.
 * Initializes Salesforce Mobile SDK (reads bootconfig from res/values/bootconfig.xml)
 * so Employee Agent auth (login) is available on the Employee settings tab.
 */
public class MainApplication extends Application implements ReactApplication {

	private final ReactNativeHost mReactNativeHost = new DefaultReactNativeHost(this) {
		@Override
		public boolean getUseDeveloperSupport() {
			return BuildConfig.DEBUG;
		}

		@Override
		protected List<ReactPackage> getPackages() {
			@SuppressWarnings("UnnecessaryLocalVariable")
			List<ReactPackage> packages = new PackageList(this).getPackages();
			// Agentforce is provided by react-native-agentforce bridge (autolinking)
			return packages;
		}

		@Override
		protected String getJSMainModuleName() {
			return "index";
		}

		@Override
		protected boolean isNewArchEnabled() {
			return BuildConfig.IS_NEW_ARCHITECTURE_ENABLED;
		}

		@Override
		protected Boolean isHermesEnabled() {
			return BuildConfig.IS_HERMES_ENABLED;
		}
	};

	@Override
	public ReactNativeHost getReactNativeHost() {
		return mReactNativeHost;
	}

	@Override
	public void onCreate() {
		super.onCreate();
		// Initialize Salesforce Mobile SDK (required for Employee Agent login; uses res/values/bootconfig.xml)
		SalesforceSDKManager.initNative(this, MainActivity.class);
		SoLoader.init(this, /* native exopackage */ false);
		if (BuildConfig.IS_NEW_ARCHITECTURE_ENABLED) {
			// If you opted-in for the New Architecture, we load the native entry point for this app.
			DefaultNewArchitectureEntryPoint.load();
		}
	}
}
