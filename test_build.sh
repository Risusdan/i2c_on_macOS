#!/bin/bash

# Test build script for studyi2c project
cd "$(dirname "$0")"

echo "🔧 Building studyi2c project..."
xcodebuild -project studyi2c.xcodeproj -scheme studyi2c build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📍 Executable location:"
    find . -name "studyi2c" -type f -executable 2>/dev/null | grep -v ".build" | head -1
    
    echo ""
    echo "🚀 To run the demo:"
    echo "sudo ./path/to/studyi2c"
    echo ""
    echo "⚠️  Note: Requires admin privileges for IOKit access"
else
    echo "❌ Build failed!"
    exit 1
fi