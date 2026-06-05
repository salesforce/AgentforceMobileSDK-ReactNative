// Logger delegate — forwards SDK logs to the JS console.
//
// If you have a logging service (Sentry, Datadog, etc.), wire it up here.

import type { LoggerDelegate, LogLevel } from 'react-native-agentforce';

export const agentforceLogger: LoggerDelegate = {
  onLog(level: LogLevel, message: string, error?: string) {
    const timestamp = new Date().toISOString();
    const prefix = `[${timestamp}][Agentforce ${level.toUpperCase()}]`;
    if (error) {
      console.log(`${prefix} ${message} | ERROR: ${error}`);
    } else {
      console.log(`${prefix} ${message}`);
    }

    // TODO: forward to your analytics / error reporting service if needed.
    // e.g. if (level === 'error') Sentry.captureMessage(message, { extra: { error } });
  },
};
