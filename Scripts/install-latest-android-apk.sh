#!/bin/bash
set -euo pipefail

# Build and install the current Tiro debug APK on one ADB-connected Android
# device. A newer local version code avoids downgrade failures, while
# `adb install -r` preserves the app's permissions, consent, and history.

# Resolve every path from this file so PanePilot can start the action from any
# working directory.
script_directory="$(cd "$(dirname "$0")" && pwd)"
repository_directory="$(cd "$script_directory/.." && pwd)"
android_directory="$repository_directory/android"
debug_apk="$android_directory/app/build/outputs/apk/debug/app-debug.apk"
debug_package="${ANDROID_PACKAGE_ID:-com.salazarprime.tiro}"

adb_command="$(command -v adb || true)"
if [[ -z "$adb_command" ]]; then
  for candidate in \
    /opt/homebrew/bin/adb \
    /usr/local/bin/adb \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "${ANDROID_HOME:-}/platform-tools/adb"; do
    if [[ -x "$candidate" ]]; then
      adb_command="$candidate"
      break
    fi
  done
fi

if [[ -z "$adb_command" ]]; then
  echo "ADB is not installed or is not available on PATH." >&2
  exit 1
fi

if [[ ! -x "$android_directory/gradlew" ]]; then
  echo "The Android submodule is missing. Run 'git submodule update --init android'." >&2
  exit 1
fi

"$adb_command" start-server >/dev/null

# ANDROID_SERIAL selects one target when multiple ADB devices are online.
requested_serial="${ANDROID_SERIAL:-}"
if [[ -n "$requested_serial" ]]; then
  if [[ "$("$adb_command" -s "$requested_serial" get-state 2>/dev/null || true)" != "device" ]]; then
    echo "ADB device '$requested_serial' is not connected and authorized." >&2
    "$adb_command" devices -l >&2
    exit 1
  fi
  device_serial="$requested_serial"
else
  connected_devices="$("$adb_command" devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
  device_count="$(printf '%s\n' "$connected_devices" | awk 'NF { count += 1 } END { print count + 0 }')"
  if [[ "$device_count" -eq 0 ]]; then
    echo "No authorized Android device is connected through ADB." >&2
    echo "Connect a device, enable USB debugging, and accept its authorization prompt." >&2
    "$adb_command" devices -l >&2
    exit 1
  fi
  if [[ "$device_count" -gt 1 ]]; then
    echo "More than one Android device is connected:" >&2
    "$adb_command" devices -l >&2
    echo "Set ANDROID_SERIAL to choose the device for this action." >&2
    exit 1
  fi
  device_serial="$connected_devices"
fi

# ANDROID_APK installs an existing APK instead of rebuilding. Its embedded
# version code is left unchanged.
requested_apk="${ANDROID_APK:-}"
if [[ -n "$requested_apk" ]]; then
  if [[ "$requested_apk" = /* ]]; then
    apk_path="$requested_apk"
  else
    apk_path="$repository_directory/$requested_apk"
  fi
else
  package_details="$("$adb_command" -s "$device_serial" shell dumpsys package "$debug_package" 2>/dev/null || true)"
  installed_version_code="$(printf '%s\n' "$package_details" | awk '
    /versionCode=/ {
      for (field = 1; field <= NF; field += 1) {
        if ($field ~ /^versionCode=[0-9]+$/) {
          sub(/^versionCode=/, "", $field)
          print $field
          exit
        }
      }
    }
  ')"
  installed_version_code="${installed_version_code:-0}"

  clock_version_code="$(date -u +%s)"
  next_version_code="$clock_version_code"
  if (( installed_version_code >= next_version_code )); then
    next_version_code=$((installed_version_code + 1))
  fi
  version_code="${ANDROID_VERSION_CODE:-$next_version_code}"
  version_name="${ANDROID_VERSION_NAME:-0.1.local.$(date -u +%Y%m%d%H%M%S)}"

  if [[ ! "$version_code" =~ ^[0-9]+$ ]] ||
    (( version_code < 1 || version_code > 2100000000 )); then
    echo "ANDROID_VERSION_CODE must be an integer between 1 and 2100000000." >&2
    exit 1
  fi
  if (( version_code <= installed_version_code )); then
    echo "Version code $version_code is not newer than installed code $installed_version_code." >&2
    exit 1
  fi

  echo "Device: $device_serial"
  echo "Installed version code: $installed_version_code"
  echo "Building version: $version_name ($version_code)"

  if [[ "${ADB_INSTALL_DRY_RUN:-0}" == "1" ]]; then
    echo "Dry run complete; the APK was not built or installed."
    exit 0
  fi

  # PanePilot can have a smaller environment than an interactive shell. Find a
  # complete SDK for Gradle when neither standard SDK variable is configured.
  android_sdk_directory=""
  if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
    for candidate in \
      "$HOME/Library/Android/sdk" \
      /opt/homebrew/share/android-commandlinetools \
      /usr/local/share/android-commandlinetools; do
      if [[ -d "$candidate/platforms" && -d "$candidate/build-tools" ]]; then
        android_sdk_directory="$candidate"
        break
      fi
    done
  fi

  (
    cd "$android_directory"
    if [[ -n "$android_sdk_directory" ]]; then
      ANDROID_HOME="$android_sdk_directory" ./gradlew assembleDebug \
        -PappVersionCode="$version_code" \
        -PappVersionName="$version_name"
    else
      ./gradlew assembleDebug \
        -PappVersionCode="$version_code" \
        -PappVersionName="$version_name"
    fi
  )
  apk_path="$debug_apk"
fi

if [[ -z "$apk_path" || ! -f "$apk_path" ]]; then
  echo "No installable APK was found at $apk_path." >&2
  exit 1
fi

if [[ -n "$requested_apk" ]]; then
  echo "Device: $device_serial"
  echo "Using the explicit APK without rebuilding its version code."
fi
echo "APK: ${apk_path#"$repository_directory/"}"

if [[ "${ADB_INSTALL_DRY_RUN:-0}" == "1" ]]; then
  echo "Dry run complete; the APK was not installed."
  exit 0
fi

if ! install_output="$("$adb_command" -s "$device_serial" install -r "$apk_path" 2>&1)"; then
  printf '%s\n' "$install_output" >&2
  if [[ "$install_output" == *"INSTALL_FAILED_UPDATE_INCOMPATIBLE"* ]]; then
    echo "The installed app has a different signature. It was not removed because uninstalling would erase its local data." >&2
  fi
  exit 1
fi

printf '%s\n' "$install_output"
echo "Installed the latest local Tiro APK while preserving app data."
