module.exports = {
  root: true,
  extends: '@react-native',
  // Generated build output of the published bridge package — never hand-edited.
  ignorePatterns: ['AgentforceSDK-ReactNative-Bridge/lib/'],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  overrides: [
    {
      files: ['*.ts', '*.tsx'],
      rules: {
        '@typescript-eslint/no-shadow': ['error'],
        'no-shadow': 'off',
        'no-undef': 'off',
      },
    },
  ],
  rules: {
    // Customizations - keep minimal to avoid disruption
    'react-native/no-inline-styles': 'warn',
    'prettier/prettier': [
      'error',
      {
        endOfLine: 'auto',
      },
    ],
  },
};
