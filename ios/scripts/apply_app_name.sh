#!/bin/sh
# Resolve e aplica o nome do app no iOS.
# Fontes (ordem): variável APPNAME > envs/.env.prod > ios/Flutter/AppName.xcconfig
#
# Uso:
#   apply_app_name.sh xcconfig
#   apply_app_name.sh plist <caminho-do-Info.plist>

set -e

SRCROOT_DIR="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT_ROOT="${SRCROOT_DIR}/.."
ENV_FILE="${PROJECT_ROOT}/envs/.env.prod"
XCCONFIG="${SRCROOT_DIR}/Flutter/AppName.xcconfig"

resolve_appname() {
  if [ -n "$APPNAME" ]; then
    printf '%s' "$APPNAME"
    return 0
  fi

  if [ -f "$ENV_FILE" ]; then
    _name=$(grep "^APPNAME=" "$ENV_FILE" 2>/dev/null | head -1 | sed "s/^APPNAME=//; s/^'//; s/'$//")
    if [ -n "$_name" ]; then
      printf '%s' "$_name"
      return 0
    fi
  fi

  if [ -f "$XCCONFIG" ]; then
    grep "^APP_DISPLAY_NAME" "$XCCONFIG" | sed 's/^APP_DISPLAY_NAME = //; s/^"\(.*\)"$/\1/'
  fi
}

escape_for_sed() {
  printf '%s' "$1" | sed 's/"/\\"/g'
}

apply_xcconfig() {
  _name=$(resolve_appname)
  if [ -z "$_name" ] || [ ! -f "$XCCONFIG" ]; then
    return 0
  fi

  _escaped=$(escape_for_sed "$_name")
  sed -i '' "s/^APP_DISPLAY_NAME = .*/APP_DISPLAY_NAME = \"${_escaped}\"/" "$XCCONFIG"
  echo "APP_DISPLAY_NAME=${_name}"
}

apply_plist() {
  _plist="$1"
  _name=$(resolve_appname)

  if [ -z "$_name" ] || [ ! -f "$_plist" ]; then
    return 0
  fi

  if /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName \"${_name}\"" "$_plist" 2>/dev/null; then
    echo "CFBundleDisplayName=${_name}"
  else
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string \"${_name}\"" "$_plist"
    echo "CFBundleDisplayName=${_name} (added)"
  fi
}

case "$1" in
  xcconfig)
    apply_xcconfig
    ;;
  plist)
    apply_plist "$2"
    ;;
  *)
    echo "Uso: $0 xcconfig | plist <Info.plist>" >&2
    exit 1
    ;;
esac
