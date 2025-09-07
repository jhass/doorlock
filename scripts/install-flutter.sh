#!/bin/bash
# Install Flutter SDK locally for development

set -e

FLUTTER_VERSION="3.27.1"
FLUTTER_DIR="/opt/flutter"

echo "🎯 Installing Flutter SDK v${FLUTTER_VERSION}..."

# Check if Flutter is already installed and working
if command -v flutter &> /dev/null; then
    echo "✅ Flutter is already installed:"
    flutter --version 2>/dev/null || echo "Flutter installed but may need dependencies"
    exit 0
fi

echo "📦 Installing Flutter SDK..."

# Try snap installation first (more reliable)
if command -v snap &> /dev/null; then
    echo "🐧 Installing Flutter via snap (recommended)..."
    if sudo snap install flutter --classic 2>/dev/null; then
        echo "✅ Flutter installed successfully via snap"
        
        # Verify installation
        echo "✅ Verifying Flutter installation..."
        flutter --version
        
        echo ""
        echo "🎉 Flutter installation completed!"
        echo ""
        exit 0
    else
        echo "⚠️  Snap installation failed, trying Git installation..."
    fi
fi

# Fallback to Git installation
echo "📥 Installing Flutter from Git repository..."

# Check if we need sudo access
if [ ! -w "$(dirname "$FLUTTER_DIR")" ]; then
    echo "🔐 Sudo access required to install Flutter to $FLUTTER_DIR"
    SUDO="sudo"
else
    SUDO=""
fi

# Remove existing installation if present
if [ -d "$FLUTTER_DIR" ]; then
    echo "🗑️ Removing existing Flutter installation..."
    $SUDO rm -rf "$FLUTTER_DIR"
fi

# Clone Flutter repository
echo "📥 Cloning Flutter repository..."
if $SUDO git clone -b stable --depth 1 https://github.com/flutter/flutter.git "$FLUTTER_DIR"; then
    echo "✅ Flutter repository cloned successfully"
else
    echo "❌ Failed to clone Flutter repository"
    exit 1
fi

# Set proper permissions
$SUDO chown -R $USER:$USER "$FLUTTER_DIR" 2>/dev/null || true

# Add Flutter to PATH for this session
export PATH="$FLUTTER_DIR/bin:$PATH"

# Basic verification - just check if flutter binary exists
if [ -f "$FLUTTER_DIR/bin/flutter" ]; then
    echo "✅ Flutter binary is available"
    echo "🔄 Dependencies will be downloaded when first needed"
else
    echo "❌ Flutter binary not found after installation"
    exit 1
fi

echo ""
echo "🎉 Flutter installation completed!"
echo ""
echo "📋 To make Flutter available in all sessions, run:"
echo "   echo 'export PATH=\"$FLUTTER_DIR/bin:\$PATH\"' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "💡 Dependencies will be downloaded automatically when you first use Flutter"
echo ""