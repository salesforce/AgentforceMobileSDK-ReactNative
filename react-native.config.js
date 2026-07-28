module.exports = {
  dependencies: {
    // Exclude react-native-force from auto-linking
    // It will be manually added only for EmployeeAgent target in Podfile
    'react-native-force': {
      platforms: {
        ios: null, // Disable auto-linking on iOS
        android: null, // Disable auto-linking on Android
      },
    },
    // Exclude the Agentforce bridge from auto-linking. The sample app consumes it
    // as an in-repo source module — Android via settings.gradle `include
    // ':react-native-agentforce'`, iOS via an explicit `pod 'ReactNativeAgentforce'
    // :path => ...` in the Podfile. Once the package was renamed to the scoped
    // '@salesforce/react-native-agentforce', autolinking additionally discovered it
    // and registered a SECOND Gradle project (:salesforce_react-native-agentforce)
    // against the same source dir (node_modules symlink), colliding on release-AAR
    // class output. Disabling autolink here keeps the single manual registration.
    '@salesforce/react-native-agentforce': {
      platforms: {
        ios: null, // Disable auto-linking on iOS (manual pod in Podfile)
        android: null, // Disable auto-linking on Android (manual include in settings.gradle)
      },
    },
  },
};
