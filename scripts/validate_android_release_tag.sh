#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: validate_android_release_tag.sh SOURCE_VERSION RELEASE_TAG LATEST_TAG TAG_SHA EVENT_SHA MAIN_SHA" >&2
  exit 2
fi

SOURCE_VERSION="$1"
RELEASE_TAG="$2"
LATEST_TAG="$3"
TAG_SHA="$4"
EVENT_SHA="$5"
MAIN_SHA="$6"

VERSION_NAME="${SOURCE_VERSION%%+*}"
if [[ ! "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Source version must be stable MAJOR.MINOR.PATCH." >&2
  exit 1
fi

if [[ ! "$RELEASE_TAG" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
  echo "Release tag must use vMAJOR.MINOR.PATCH+BUILD_NUMBER." >&2
  exit 1
fi
TAG_VERSION="${BASH_REMATCH[1]}"
BUILD_NUMBER="${BASH_REMATCH[2]}"

if [[ "$TAG_VERSION" != "$VERSION_NAME" ]]; then
  echo "Release tag version $TAG_VERSION does not match source version $VERSION_NAME." >&2
  exit 1
fi

if [[ -z "$TAG_SHA" || "$TAG_SHA" != "$EVENT_SHA" || "$EVENT_SHA" != "$MAIN_SHA" ]]; then
  echo "Release tag must point to the exact current main HEAD." >&2
  exit 1
fi

LATEST_CLEAN="${LATEST_TAG#v}"
if [[ ! "$LATEST_CLEAN" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)$ ]]; then
  echo "Latest release tag is malformed: $LATEST_TAG" >&2
  exit 1
fi
LATEST_VERSION="${BASH_REMATCH[1]}"
LATEST_BUILD="${BASH_REMATCH[2]}"

if (( BUILD_NUMBER <= LATEST_BUILD )); then
  echo "Android versionCode $BUILD_NUMBER is not greater than latest build $LATEST_BUILD." >&2
  exit 1
fi

if dpkg --compare-versions "$VERSION_NAME" lt "$LATEST_VERSION"; then
  echo "Candidate $RELEASE_TAG is older than latest release $LATEST_TAG." >&2
  exit 1
fi

printf '%s\t%s\t%s\n' "$VERSION_NAME" "$BUILD_NUMBER" "$RELEASE_TAG"
