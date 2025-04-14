#!/bin/sh

# Check if 'act' is installed
if ! command -v act >/dev/null 2>&1; then
  echo "'act' is not installed."

  # Try to install if Homebrew is available
  if command -v brew >/dev/null 2>&1; then
    echo "Installing 'act' with Homebrew..."
    brew install act
    if [ $? -ne 0 ]; then
      echo "Failed to install 'act' with Homebrew."
      exit 1
    fi
  else
    echo "Please install 'act' manually: https://github.com/nektos/act#installation"
    exit 1
  fi
fi

echo "'act' is available. Running GitHub Actions locally..."

# Run 'act' with the 'push' event
act -W ../.github/workflows/integration-test.yml
status=$?

if [ "$status" -ne 0 ]; then
  echo "act failed, aborting push."
  exit 1
else
  echo "act passed, proceeding with push."
  exit 0
fi
