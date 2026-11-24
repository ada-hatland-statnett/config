#!/usr/bin/env bash
# Compile settings.kts for diagnostics without executing the TeamCity script.
set -eu -o pipefail
script=$1
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
exec 2>&1

# These TeamCity projects use a standalone Maven descriptor. Keep all build
# output here, and resolve from the local Maven repository on editor saves.
cp -- "$(dirname "$script")/pom.xml" pom.xml
mvn -B -q -o dependency:build-classpath -Dmdep.outputFile=classpath
# Maven includes dependency descriptors as well as compiler libraries.
jars=$(tr ':' '\n' < classpath | awk '/\.jar$/')
classpath=$(paste -sd: <<< "$jars")
mise exec kotlin@2.1.21 -- kotlinc -Xuse-fir-lt=false -Xallow-any-scripts-in-source-roots \
  -classpath "$classpath" "$script" -d checked.jar
