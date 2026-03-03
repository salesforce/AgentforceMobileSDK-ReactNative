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
  },
};
