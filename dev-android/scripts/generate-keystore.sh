#!/bin/bash

# Script to generate Android keystore for signing APKs
# Usage: ./generate-keystore.sh

KEYSTORE_FILE="keystore.jks"
KEY_ALIAS="myapp"
VALIDITY_DAYS=10000

echo "======================================"
echo "Android Keystore Generation Script"
echo "======================================"
echo ""

# Check if keystore already exists
if [ -f "$KEYSTORE_FILE" ]; then
    echo "Warning: Keystore file '$KEYSTORE_FILE' already exists."
    read -p "Do you want to overwrite it? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        echo "Aborting."
        exit 1
    fi
    rm "$KEYSTORE_FILE"
fi

# Prompt for passwords
read -sp "Enter keystore password: " KEYSTORE_PASSWORD
echo
read -sp "Confirm keystore password: " KEYSTORE_PASSWORD_CONFIRM
echo

if [ "$KEYSTORE_PASSWORD" != "$KEYSTORE_PASSWORD_CONFIRM" ]; then
    echo "Error: Passwords do not match."
    exit 1
fi

read -sp "Enter key password (or press Enter to use the same as keystore): " KEY_PASSWORD
echo

if [ -z "$KEY_PASSWORD" ]; then
    KEY_PASSWORD="$KEYSTORE_PASSWORD"
fi

# Prompt for certificate information
echo ""
echo "Enter certificate details:"
read -p "First and Last Name (CN): " CN
read -p "Organizational Unit (OU): " OU
read -p "Organization (O): " O
read -p "City or Locality (L): " L
read -p "State or Province (ST): " ST
read -p "Country Code (C, 2 letters): " C

# Generate keystore
echo ""
echo "Generating keystore..."
keytool -genkeypair \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity $VALIDITY_DAYS \
    -keystore "$KEYSTORE_FILE" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C"

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "Keystore generated successfully!"
    echo "======================================"
    echo ""
    echo "File: $KEYSTORE_FILE"
    echo "Alias: $KEY_ALIAS"
    echo ""
    echo "IMPORTANT: Keep this keystore file and passwords secure!"
    echo "You will need them to sign your app for release."
    echo ""
    echo "For GitHub Actions, add these secrets to your repository:"
    echo "1. KEYSTORE_BASE64: base64 encoded keystore file"
    echo "   Run: base64 -w 0 $KEYSTORE_FILE"
    echo "2. KEYSTORE_PASSWORD: $KEYSTORE_PASSWORD"
    echo "3. KEY_ALIAS: $KEY_ALIAS"
    echo "4. KEY_PASSWORD: (the key password you entered)"
    echo ""
    echo "To encode keystore for GitHub secrets:"
    echo "  base64 -w 0 $KEYSTORE_FILE | pbcopy  # macOS"
    echo "  base64 -w 0 $KEYSTORE_FILE | xclip   # Linux"
    echo ""
else
    echo ""
    echo "Error: Failed to generate keystore."
    exit 1
fi
