#!/bin/bash
# Make all Linux scripts executable
# Run this script once after cloning the repository

echo "Making all Linux scripts executable..."

# Navigate to the linux directory
cd "$(dirname "$0")"

# Make all .sh files executable
chmod +x *.sh

echo "✅ All scripts are now executable!"
echo ""
echo "Available scripts:"
ls -lh *.sh | awk '{print "  " $9 " (" $5 ")"}'
