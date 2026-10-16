#!/usr/bin/env bash
set -e

# Change directory to Flutter project if currently at root
if [ -d "apps/chat_app" ]; then
  cd apps/chat_app
fi

# Locate Flutter executable or clone stable Flutter SDK
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="flutter"
elif [ -x "flutter/bin/flutter" ]; then
  FLUTTER_BIN="flutter/bin/flutter"
elif [ -x "../flutter/bin/flutter" ]; then
  FLUTTER_BIN="../flutter/bin/flutter"
else
  echo "Cloning Flutter SDK (stable branch)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
  FLUTTER_BIN="flutter/bin/flutter"
fi

echo "Pre-caching Web artifacts..."
$FLUTTER_BIN precache --web

# Assemble --dart-define arguments from Vercel environment variables
DART_ARGS=""
if [ -n "$API_BASE_URL" ]; then
  DART_ARGS="$DART_ARGS --dart-define=API_BASE_URL=$API_BASE_URL"
fi
if [ -n "$WS_BASE_URL" ]; then
  DART_ARGS="$DART_ARGS --dart-define=WS_BASE_URL=$WS_BASE_URL"
fi
if [ -n "$SUPABASE_URL" ]; then
  DART_ARGS="$DART_ARGS --dart-define=SUPABASE_URL=$SUPABASE_URL"
fi
if [ -n "$SUPABASE_ANON_KEY" ]; then
  DART_ARGS="$DART_ARGS --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
fi

echo "Building Flutter Web release bundle..."
$FLUTTER_BIN build web --release $DART_ARGS -t lib/main.dart

echo "Flutter web build completed successfully!"
