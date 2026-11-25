#!/bin/bash
set -euo pipefail
ios_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/yuto-core.XXXXXX")"
trap 'rm -f "$build_dir/checks"; rmdir "$build_dir"' EXIT
swiftc -module-cache-path /tmp/yuto-swift-module-cache \
    "$ios_dir"/Domain/Models/*.swift "$ios_dir"/Domain/Services/*.swift \
    "$ios_dir"/Data/TravelPreferences.swift "$ios_dir"/App/TravelStore.swift \
    "$ios_dir"/Tests/TravelCoreChecks.swift -o "$build_dir/checks"
"$build_dir/checks" "$ios_dir/Resources/Catalog.json"
