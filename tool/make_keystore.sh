#!/usr/bin/env bash
# One-time: creates your Android upload key and stores it in GitHub secrets.
# Run from the repository folder in Termux:  bash tool/make_keystore.sh
set -euo pipefail

command -v keytool >/dev/null 2>&1 || { echo "keytool is missing. Run:  pkg install openjdk-17   then run this again."; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is missing."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "You are not logged in to GitHub. Run:  gh auth login"; exit 1; }

DIR="$HOME/campusstay-keys"
KS="$DIR/campusstay-upload.jks"
ALIAS="campusstay"

mkdir -p "$DIR"
chmod 700 "$DIR"
if [ -e "$KS" ]; then
  echo "A key already exists at $KS."
  echo "I will NOT replace it: a new key could not update an app that is already published."
  echo "If you only need to set the GitHub secrets again, tell me and I will give you that command."
  exit 1
fi

# Letters and numbers only, so the password is safe in any file or command.
PASS="$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"

keytool -genkeypair -noprompt -storetype JKS \
  -keystore "$KS" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=CampusStay, O=CampusStay, C=NG"

umask 077
{
  echo "CampusStay Android upload key. KEEP THIS SAFE. DO NOT SHARE. DO NOT PUT IT ON GITHUB."
  echo "File:     $KS"
  echo "Alias:    $ALIAS"
  echo "Password: $PASS"
} > "$DIR/KEY-DETAILS.txt"

base64 -w0 "$KS" | gh secret set KEYSTORE_BASE64
printf '%s' "$PASS"  | gh secret set KEYSTORE_PASSWORD
printf '%s' "$PASS"  | gh secret set KEY_PASSWORD
printf '%s' "$ALIAS" | gh secret set KEY_ALIAS

echo
echo "Done. Your key is in:  $DIR"
echo "  - campusstay-upload.jks   (the key)"
echo "  - KEY-DETAILS.txt         (alias and password)"
echo
echo "IMPORTANT: copy that whole folder somewhere safe NOW (Google Drive, a USB stick, email to yourself)."
echo "GitHub can use the key but can never give it back. If you lose it, you cannot update a published app."
