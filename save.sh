#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <project.xcodeproj> <scheme> <commit-message> [git-remote]"
  echo "Example: $0 QuranReader.xcodeproj QuranReader \"Reader: refine navigation\""
  exit 1
fi

project_path="$1"
scheme_name="$2"
commit_message="$3"
git_remote="${4:-origin}"

echo "Checking git status..."
GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1

echo "Building project..."
xcodebuild \
  -project "$project_path" \
  -scheme "$scheme_name" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build

echo "Saving changes..."
git add -A
git commit -m "$commit_message"
git push "$git_remote" HEAD

echo "Done."
