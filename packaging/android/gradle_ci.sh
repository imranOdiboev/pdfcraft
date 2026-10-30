#!/usr/bin/env bash
set -euo pipefail
# Build tooling exists only in the disposable Actions environment.
version=8.13
destination="${RUNNER_TEMP:?}/odibo-gradle-$version"
archive="$destination.zip"
curl --fail --location --retry 3 "https://services.gradle.org/distributions/gradle-$version-bin.zip" -o "$archive"
curl --fail --location --retry 3 "https://services.gradle.org/distributions/gradle-$version-bin.zip.sha256" -o "$archive.sha256"
checksum="$(tr -d '\r\n' < "$archive.sha256")"
[[ "$checksum" =~ ^[0-9a-f]{64}$ ]]
echo "$checksum  $archive" | sha256sum --check --strict
mkdir "$destination"
unzip -q "$archive" -d "$destination"
printf 'ODIBO_GRADLE=%s/gradle-%s/bin/gradle\n' "$destination" "$version" >> "$GITHUB_ENV"
