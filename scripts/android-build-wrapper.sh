#!/bin/bash

# Android build wrapper - exports REACT_NATIVE_BOOST_PATH for Gradle builds
# Usage: This script is called by npm build scripts (build:android:service, build:android:employee)

# Read REACT_NATIVE_BOOST_PATH from local.properties
BOOST_PATH=$(grep "^REACT_NATIVE_BOOST_PATH=" android/local.properties 2>/dev/null | cut -d'=' -f2)

if [ -z "$BOOST_PATH" ]; then
  echo ""
  echo "❌ Android not configured. Run setup first:"
  echo ""
  echo "   node installandroid.js employee"
  echo ""
  echo "   (or 'service' or 'all' depending on which app you want to build)"
  echo ""
  exit 1
fi

# Export as environment variable so React Native Gradle can read it
export REACT_NATIVE_BOOST_PATH="$BOOST_PATH"

# Change to android directory and run gradlew with provided arguments
cd android && ./gradlew "$@"
