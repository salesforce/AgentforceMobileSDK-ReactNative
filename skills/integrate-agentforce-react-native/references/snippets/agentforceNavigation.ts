// Navigation delegate — handles SDK navigation requests in JS instead of
// letting the native SDK handle them.
//
// Use this to route record opens / link taps / quick actions through your
// own React Navigation stack, deep linking, or in-app browser.

import { Alert, Linking } from 'react-native';
import type { NavigationDelegate, NavigationRequest } from 'react-native-agentforce';

export const agentforceNavigation: NavigationDelegate = {
  onNavigate(request: NavigationRequest) {
    // Known request.type values: 'record', 'link', 'quickAction',
    // 'pageReference', 'objectHome', 'app', 'unknown'
    switch (request.type) {
      case 'link': {
        const uri = request.uri as string | undefined;
        if (uri) Linking.openURL(uri);
        break;
      }
      case 'record': {
        // TODO: navigate to your record detail screen, e.g.
        //   navigationRef.navigate('RecordDetail', {
        //     recordId: request.recordId,
        //     objectType: request.objectType,
        //   });
        console.log(`[Agentforce Nav] record: ${request.objectType} ${request.recordId}`);
        break;
      }
      case 'quickAction': {
        // TODO: invoke your in-app quick action handler
        console.log(`[Agentforce Nav] quickAction: ${request.actionName}`);
        break;
      }
      default:
        // Useful while developing — replace with silent handling in production
        Alert.alert('Navigation Request', JSON.stringify(request, null, 2));
    }
  },
};
