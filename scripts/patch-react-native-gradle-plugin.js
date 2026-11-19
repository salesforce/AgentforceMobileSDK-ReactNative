// Match the React Native Gradle plugin to the Android app's AGP/Kotlin versions.
// This runs after npm install and from installandroid.js, which skips lifecycle scripts.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const versionsPath = 'node_modules/@react-native/gradle-plugin/gradle/libs.versions.toml';

function applyPatch(label, relativePath, before, after) {
  const targetPath = path.join(root, relativePath);
  if (!fs.existsSync(targetPath)) {
    throw new Error(`Missing React Native Gradle plugin file: ${relativePath}`);
  }
  const content = fs.readFileSync(targetPath, 'utf8');
  if (content.includes(after)) {
    console.log(`   Already aligned: ${label}`);
  } else if (content.includes(before)) {
    fs.writeFileSync(targetPath, content.replace(before, after), 'utf8');
    console.log(`   Updated ${label}`);
  } else {
    throw new Error(`Unexpected React Native Gradle plugin ${label} in ${relativePath}`);
  }
}

console.log('Aligning React Native Gradle plugin versions...');
applyPatch('Kotlin version', versionsPath, 'kotlin = "2.0.21"', 'kotlin = "2.2.0"');
applyPatch('AGP version', versionsPath, 'agp = "8.7.2"', 'agp = "8.9.1"');
for (const plugin of [
  'react-native-gradle-plugin',
  'settings-plugin',
  'shared',
  'shared-testutil',
]) {
  applyPatch(
    `${plugin} Kotlin API`,
    `node_modules/@react-native/gradle-plugin/${plugin}/build.gradle.kts`,
    'apiVersion.set(KotlinVersion.KOTLIN_1_7)',
    'apiVersion.set(KotlinVersion.KOTLIN_1_9)',
  );
}
