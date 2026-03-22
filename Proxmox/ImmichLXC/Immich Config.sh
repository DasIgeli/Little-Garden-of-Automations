set -e

UPLOAD_ROOT="/opt/immich/app/upload"

CACHE_DST="/mnt/immich_appconfig"
INGEST_DST="/mnt/immich_ingest"
LIBRARY_DST="/mnt/immich_library"

ENV_FILE="/opt/immich/.env"

echo "🛑 Stopping Immich services..."
systemctl stop immich-web immich-ml

echo "📄 Checking mountpoints..."
for dir in "$CACHE_DST" "$INGEST_DST" "$LIBRARY_DST"; do
    if [ ! -d "$dir" ]; then
        echo "❌ Directory $dir does not exist. Mount your NAS first!"
        exit 1
    fi
done

echo "📁 Ensuring target structure..."
mkdir -p \
  "$CACHE_DST/thumbs" \
  "$CACHE_DST/encoded-video" \
  "$CACHE_DST/profile" \
  "$CACHE_DST/backups" \
  "$INGEST_DST/upload" \
  "$LIBRARY_DST/library"

# Create .immich marker file in each subfolder
touch "$CACHE_DST/thumbs/.immich"
touch "$CACHE_DST/encoded-video/.immich"
touch "$CACHE_DST/profile/.immich"
touch "$CACHE_DST/backups/.immich"
touch "$INGEST_DST/upload/.immich"
touch "$LIBRARY_DST/library/.immich"

echo "⚙️ Fixing .env (local root only!)..."
if grep -q "^IMMICH_MEDIA_LOCATION=" "$ENV_FILE"; then
    sed -i "s|^IMMICH_MEDIA_LOCATION=.*|IMMICH_MEDIA_LOCATION=$UPLOAD_ROOT|" "$ENV_FILE"
else
    echo "IMMICH_MEDIA_LOCATION=$UPLOAD_ROOT" >> "$ENV_FILE"
fi

echo "📦 Migrating existing data (if any)..."

move_if_exists() {
    SRC="$1"
    DST="$2"

    if [ -d "$SRC" ] && [ ! -L "$SRC" ]; then
        echo "➡️ Moving $SRC → $DST"
        cp -a "$SRC/"* "$DST"/ 2>/dev/null || true
        rm -rf "$SRC"
    fi
}

move_if_exists "$UPLOAD_ROOT/library" "$LIBRARY_DST/library"
move_if_exists "$UPLOAD_ROOT/upload" "$INGEST_DST/upload"
move_if_exists "$UPLOAD_ROOT/thumbs" "$CACHE_DST/thumbs"
move_if_exists "$UPLOAD_ROOT/encoded-video" "$CACHE_DST/encoded-video"
move_if_exists "$UPLOAD_ROOT/profile" "$CACHE_DST/profile"
move_if_exists "$UPLOAD_ROOT/backups" "$CACHE_DST/backups"

echo "🔗 Creating symlinks..."

ln -sfn "$LIBRARY_DST/library" "$UPLOAD_ROOT/library"
ln -sfn "$INGEST_DST/upload" "$UPLOAD_ROOT/upload"

ln -sfn "$CACHE_DST/thumbs" "$UPLOAD_ROOT/thumbs"
ln -sfn "$CACHE_DST/encoded-video" "$UPLOAD_ROOT/encoded-video"
ln -sfn "$CACHE_DST/profile" "$UPLOAD_ROOT/profile"
ln -sfn "$CACHE_DST/backups" "$UPLOAD_ROOT/backups"

echo "🔧 Fixing machine-learning symlink..."
rm -f /opt/immich/app/machine-learning/upload
ln -sfn "$UPLOAD_ROOT" /opt/immich/app/machine-learning/upload

echo "🔒 Adjusting ownership..."
chown -R immich:immich /opt/immich

echo "🧠 Updating media paths in DB..."
cd /opt/immich/app/bin
if [ -f "./immich-admin" ]; then
    ./immich-admin change-media-location || echo "⚠️ Verify manually."
fi

echo "🚀 Restarting services..."
systemctl start immich-ml immich-web

echo "🧩 Logs:"
tail -n 10 /var/log/immich/web.log || true

echo "✅ Done"