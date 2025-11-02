#!/bin/bash

# Test MinIO S3 Storage
# Run from project root: ./scripts/test-minio.sh

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found in project root"
    exit 1
fi

echo "Testing MinIO S3 storage..."
echo "Using MinIO at http://localhost:9000"
echo "Web Console at http://localhost:9001"
echo "Credentials: ${MINIO_ROOT_USER} / [hidden]"
echo ""

# Wait for MinIO to be ready
echo "Waiting for MinIO to start..."
sleep 5

# Install mc (MinIO Client) in container if not present and create buckets
docker exec integration-minio sh -c "
    # Download mc client
    wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
    
    # Configure mc with local MinIO
    mc alias set local http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}
    
    # Create buckets
    mc mb local/${MINIO_BUCKET_PROCESSED} --ignore-existing
    mc mb local/${MINIO_BUCKET_ERRORS} --ignore-existing
    
    # List buckets
    echo 'Created buckets:'
    mc ls local/
    
    # Create test folders
    echo 'Test file' | mc pipe local/${MINIO_BUCKET_PROCESSED}/test.txt
    echo 'Error file' | mc pipe local/${MINIO_BUCKET_ERRORS}/test-error.txt
    
    # Show bucket contents
    echo ''
    echo 'Processed bucket contents:'
    mc ls local/${MINIO_BUCKET_PROCESSED}/
    
    echo ''
    echo 'Errors bucket contents:'
    mc ls local/${MINIO_BUCKET_ERRORS}/
"

echo ""
echo "✅ MinIO setup complete!"
echo "📁 Buckets created: ${MINIO_BUCKET_PROCESSED}, ${MINIO_BUCKET_ERRORS}"
echo "🌐 Web Console: http://localhost:9001 (login: ${MINIO_ROOT_USER})"
