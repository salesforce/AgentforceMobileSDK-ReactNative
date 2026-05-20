---
name: integrate-agentforce-react-native
description: Integrate the Agentforce Mobile SDK into an existing React Native app. Walks the consumer through use-case discovery, picks the right configuration (Service Agent for public/customer-facing, Employee Agent for signed-in workforce), wires the `react-native-agentforce` bridge package + native iOS/Android dependencies, and scaffolds TypeScript files for the AgentforceService configuration, logger/navigation/view-provider delegates, and a launch button. Use when a developer asks to "add Agentforce", "integrate the Agentforce SDK", "set up Agentforce chat", or wire a React Native app up to a Salesforce agent.
---

# integrate-agentforce-react-native

This skill walks a consumer through wiring the **Agentforce Mobile SDK** (via the `react-native-agentforce` bridge) into their React Native app. It is **interactive** — ask the user the questions in each phase before generating code. Don't assume; the wrong configuration mode is the most common integration mistake.

## Operating rules

- **Run inside the consumer's React Native project, not inside the SDK repo.** If the working directory contains `AgentforceSDK-ReactNative-Bridge/` as a sibling of `package.json`, refuse and tell the user to `cd` into their consuming app.
- **Discover before deciding.** Always run Phase 1 (use-case discovery) before recommending a config mode. Don't ask "Service Agent or Employee Agent?" — most consumers don't know what those map to.
- **Employee Agent requires the host app to bring its own Salesforce Mobile SDK** for OAuth. The bridge does **not** bundle it. Surface this _before_ scaffolding so the user can confirm they have it (or are willing to add it).
- **Use `AskUserQuestion` for branching choices.** Don't free-text prompts — give 2–4 explicit options.
- **Substitute placeholders, don't leave `{{TOKENS}}` in the final files.** Collect values up front; if the user can't provide a value, leave a clearly-marked `// TODO:` comment instead.
- **Configuration must precede `launchConversation()`.** Document this in scaffolded files; it's a common cause of runtime failures.

## Phase 0 — Detect the target project

Look in the current working directory for:

- `package.json` with `react-native` in `dependencies` or `peerDependencies`
- `ios/` and `android/` folders (bare React Native; required — the bridge is iOS/Android only)
- `app.json` or `metro.config.js` to confirm

If none is present, ask the user where the React Native project root is and `cd` there. If the directory contains `AgentforceSDK-ReactNative-Bridge/` at the root and the package name is `react-native-agentforce-sample` or similar, refuse — that's this SDK's own repo.

**Expo managed workflow is not supported** — the bridge requires native code. If you detect `expo` in `package.json` _without_ `ios/` and `android/` folders, tell the user they need to `expo prebuild` (or migrate to a bare workflow) first.

See `references/dep-detection.md` for the full setup checklist.

## Phase 1 — Discover the use case (this drives configuration mode)

Ask **first** what they're building, then map to a configuration mode:

```
AskUserQuestion: "What kind of agent are you integrating?"
  - Public service agent (customer-facing, no sign-in)        → ServiceAgentConfig (type: 'service')
  - Employee agent (signed-in workforce users)                → EmployeeAgentConfig (type: 'employee')
  - Other / not sure                                           → see references/auth-flows.md
```

### Branch A — Public service agent

This is the **simplest** path:

- Use `AgentforceService.configure({ type: 'service', serviceApiURL, organizationId, esDeveloperName })`.
- The bridge handles guest/anonymous auth automatically — no OAuth, no Mobile SDK, **no token plumbing required**.
- Tell the user they'll need a **Messaging-for-In-App-Web (MIAW) mobile deployment** in their Salesforce org first, and link the docs:
  - https://help.salesforce.com/s/articleView?id=service.miaw_deployment_mobile.htm&type=5
- If they don't have one yet, pause here. The skill can't proceed without `serviceApiURL`, `organizationId`, and `esDeveloperName` from the deployment.

### Branch B — Employee agent

Employee Agent requires **OAuth credentials**. The host app must:

1. Add the **Salesforce Mobile SDK** to the native iOS/Android sides (the bridge does not bundle it).
2. Configure **bootconfig** and initialize the Mobile SDK at app start.
3. Either pass `accessToken` directly to `AgentforceService.configure(...)`, **or** rely on the in-bridge `EmployeeAgentAuthBridge` which fetches credentials from the running Mobile SDK.

Ask the follow-up:

```
AskUserQuestion: "Does this app already use the Salesforce Mobile SDK for login?"
  - Yes (Mobile SDK is already wired up)   → use EmployeeAgentAuthBridge (login/logout/credentials)
  - No (we'll add it)                      → link Mobile SDK setup docs, pause for confirmation
  - We have our own OAuth flow             → pass accessToken directly to configure()
```

Mobile SDK setup docs to link when they need them:

- iOS: https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/ios_introduction.htm
- Android: https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/android_introduction.htm
- Connected App / OAuth setup: https://developer.salesforce.com/docs/atlas.en-us.mobile_sdk.meta/mobile_sdk/oauth_configure_connected_app.htm

For employee scaffolding, use `references/snippets/configure-employee.ts`. For Mobile-SDK-driven auth, also include `references/snippets/employee-auth.ts` (calls `loginForEmployeeAgent()` / `getEmployeeAgentCredentials()`).

### Branch C — Other / not sure

Walk them through `references/auth-flows.md`. The two extra notes to surface here:

- The bridge currently exposes **two** modes: `service` and `employee`. There's no third "guest with explicit URL" mode like the native SDKs have — Service Agent already handles unauthenticated/public chat.
- If the consumer wants a public agent that doesn't go through MIAW (e.g. Agent API behind an Experience Cloud site without a service deployment), the bridge doesn't support it directly — surface this and ask whether they want to build a thin wrapper or wait for first-class support.

## Phase 2 — Pick where to launch the conversation

The bridge launches a **native** conversation UI (the iOS/Android SDK's pre-built chat surface) — there is no React Native chat component to embed inline. So the choice is just _where in your RN app the launch trigger lives_:

```
AskUserQuestion: "Where should the launch trigger live?"
  - A prominent button on a Home screen (recommended)        → ChatLaunchButton.tsx
  - In a navigation bar or header (icon button)              → HeaderLaunchButton.tsx
  - Auto-launch on first app open (after configuration)      → AutoLaunchOnMount.tsx
  - Custom — I'll wire it up myself                          → just provide configure() snippet
```

Each option corresponds to one snippet in `references/snippets/`. The launch trigger calls `AgentforceService.launchConversation()` — the native SDK takes over UI from there until the user closes the conversation.

## Phase 3 — Collect config values

Based on the chosen branch:

| Branch                  | Required values                                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Service Agent           | `serviceApiURL`, `organizationId`, `esDeveloperName`                                                                      |
| Employee + Mobile SDK   | `instanceUrl`, `organizationId`, `userId`, `agentId` (or omit for multi-agent), Connected App Consumer Key + Callback URL |
| Employee + direct token | All of the above plus `accessToken` (and a refresh strategy)                                                              |

Ask one question per missing value. If the user gives "I don't know" for a Service Agent value, point them back at the MIAW deployment link and stop.

For Employee Agent without an existing Mobile SDK setup, also collect:

- **Consumer Key** (from the Connected App)
- **Callback URL** (from the Connected App, e.g. `myapp://oauth/callback`)

These get written into the iOS `bootconfig.plist` / Android `bootconfig.xml` during Mobile SDK setup. The skill does **not** automate Mobile SDK installation — surface the install commands and pause:

```bash
# iOS — Salesforce Mobile SDK pods (in your Podfile)
pod 'SalesforceSDKCommon'
pod 'SalesforceAnalytics'
pod 'SalesforceSDKCore'
pod 'SmartStore'
pod 'MobileSync'
pod 'SalesforceReact'
```

```kotlin
// Android — in app/build.gradle.kts (Kotlin DSL) or app/build.gradle (Groovy)
implementation("com.salesforce.mobilesdk:SalesforceReact:13.1.1")
```

## Phase 4 — Add the bridge dependency

The bridge ships as a local package `react-native-agentforce`. Two install paths:

### Path 1: Install from this repo (recommended for now)

```bash
# Add the bridge package as a tarball or git dependency
npm install salesforce/AgentforceMobileSDK-ReactNative#dev --save
# or, if the bridge is published to a registry your org uses:
npm install react-native-agentforce
```

Then run the platform install scripts shipped with the bridge (these patch CocoaPods / Gradle, install Boost, etc.):

```bash
node node_modules/react-native-agentforce/installios.js service   # or 'employee' / 'all'
node node_modules/react-native-agentforce/installandroid.js service
```

### Path 2: In-repo bridge (for forks / patches)

If the consumer is forking or contributing back, vendor `AgentforceSDK-ReactNative-Bridge/` into their repo and reference it via npm:

```json
{
  "dependencies": {
    "react-native-agentforce": "file:./AgentforceSDK-ReactNative-Bridge"
  }
}
```

See `references/dep-detection.md` for the full Podfile / Gradle / Boost / XcodeGen setup.

## Phase 5 — Scaffold TypeScript files

Create the directory `src/agentforce/` (or `agentforce/` at the project root if the consumer doesn't use `src/`) and write:

| File                      | When                       | Source snippet                                                                                             |
| ------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `agentforceConfig.ts`     | Always                     | `snippets/configure-service.ts` or `configure-employee.ts` based on Phase 1                                |
| `agentforceLogger.ts`     | Always                     | `snippets/agentforceLogger.ts`                                                                             |
| `agentforceNavigation.ts` | Always                     | `snippets/agentforceNavigation.ts`                                                                         |
| `employeeAuth.ts`         | Employee + Mobile SDK only | `snippets/employee-auth.ts`                                                                                |
| `ChatLaunchButton.tsx`    | Always                     | one of `snippets/ChatLaunchButton.tsx`, `HeaderLaunchButton.tsx`, `AutoLaunchOnMount.tsx` based on Phase 2 |

The configuration helper exposes a single `configureAgentforce()` function that calls `setLoggerDelegate(...)` and `setNavigationDelegate(...)` first, then `configure(...)`. Order matters — register delegates **before** configuring so the logger captures init-time SDK output.

## Phase 6 — Wire it into App startup

Patch the consumer's `App.tsx` (or root component) to call `configureAgentforce()` once at mount, with a loading state until it resolves:

```tsx
const [ready, setReady] = useState(false);

useEffect(() => {
  configureAgentforce().then(() => setReady(true));
  return () => AgentforceService.destroy();
}, []);

if (!ready) return <LoadingScreen />;
```

If the user has an existing app with state management (Redux, Zustand, React Query, etc.), surface that instead — fold the configure call into their bootstrap action rather than `useEffect` in `App.tsx`.

## Phase 7 — Verify

Tell the user:

1. **Install native deps**:
   - iOS: `cd ios && pod install` (the bridge install script will have run `xcodegen` and patched `boost.podspec` if Boost is installed via Homebrew).
   - Android: `cd android && ./gradlew :app:dependencies` to confirm `AgentforceSDK-ReactNative-Bridge` resolved.
2. **Build**:
   - iOS: `npm run ios` (or `npx react-native run-ios`).
   - Android: `npm run android` (or `npx react-native run-android`).
3. **Logs**:
   - JavaScript: Metro bundler output, plus your `LoggerDelegate` console line.
   - iOS native: Xcode console.
   - Android native: `npx react-native log-android` or Android Studio Logcat (filter `AgentforceSDK`).
4. **Service Agent**: tap the launch button, verify the native conversation UI opens, send a test utterance, see the response.
5. **Employee Agent**: confirm `isEmployeeAgentAuthSupported()` returns `true` (Mobile SDK is wired up), then `loginForEmployeeAgent()` opens the OAuth screen, then launch.

If the build fails, common causes:

- **iOS** — missing `xcodegen` (`brew install xcodegen`) or missing Boost (`brew install boost`).
- **iOS** — `pod install` fails with version conflicts on `SalesforceReact` if Mobile SDK and bridge versions don't agree. Check `ios/Podfile.lock`.
- **Android** — wrong JDK (need 17), or Boost not exported via `REACT_NATIVE_BOOST_PATH`.
- **Both** — `AgentforceModule native module not found` at runtime usually means autolinking didn't run; restart Metro with `npm start -- --reset-cache`.
- **Employee Agent** — `Employee Agent auth is not available` from `loginForEmployeeAgent()` means the Mobile SDK isn't initialized. Check bootconfig and SDK init.

## References

- `references/auth-flows.md` — Service vs Employee Agent decision tree, Mobile SDK requirements, how `EmployeeAgentAuthBridge` interacts with the native Mobile SDK.
- `references/api-reference.md` — `AgentforceService` method walkthrough: `configure`, `launchConversation`, `setAdditionalContext`, `setLoggerDelegate`, `setNavigationDelegate`, `setViewProviderDelegate`, `registerHiddenPreChatFields`.
- `references/dep-detection.md` — Podfile, Gradle, Boost, XcodeGen, install scripts.
- `references/chat-presentation.md` — Where to put the launch trigger in your RN navigation hierarchy. The chat UI itself is native; you can't embed it inside an RN view.
- `references/snippets/*.ts(x)` — File templates with `{{PLACEHOLDERS}}` to substitute.
