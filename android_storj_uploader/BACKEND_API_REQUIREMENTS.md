# Backend API Requirements for Android App

This document outlines the backend API endpoint that needs to be implemented in `storj_uploader_backend_api_container_app` to support the Android app's functionality for displaying Storj-stored images.

## Overview

The Android app now displays photos in a grid view, showing both local photos and photos stored in Storj cloud storage. To support this functionality, a new backend API endpoint is required to fetch the list of images stored in Storj.

## Required Endpoint

### GET /storj/images

**Purpose**: Retrieve a list of images stored in Storj cloud storage with their metadata.

#### Request Parameters

All parameters are optional query parameters:

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `limit` | integer | No | 100 | Maximum number of images to return |
| `offset` | integer | No | 0 | Offset for pagination (skip N images) |
| `bucket` | string | No | default bucket | Specific Storj bucket name to query |

#### Example Requests

```bash
# Get first 100 images
GET /storj/images

# Get 50 images with pagination
GET /storj/images?limit=50&offset=100

# Get images from specific bucket
GET /storj/images?bucket=my-photos-bucket&limit=20
```

#### Response Format

**Success Response (200 OK)**:

```json
{
  "success": true,
  "images": [
    {
      "filename": "photo_20250110_abc123.jpg",
      "path": "202501/photo_20250110_abc123.jpg",
      "size": 2457600,
      "modified_time": "2025-01-10T12:34:56Z",
      "thumbnail_url": "http://api.example.com/storj/thumbnail/202501/photo_20250110_abc123.jpg",
      "url": "http://api.example.com/storj/download/202501/photo_20250110_abc123.jpg"
    },
    {
      "filename": "photo_20250110_def456.jpg",
      "path": "202501/photo_20250110_def456.jpg",
      "size": 3145728,
      "modified_time": "2025-01-10T14:22:10Z",
      "thumbnail_url": "http://api.example.com/storj/thumbnail/202501/photo_20250110_def456.jpg",
      "url": "http://api.example.com/storj/download/202501/photo_20250110_def456.jpg"
    }
  ],
  "total_count": 245,
  "message": "Successfully retrieved 2 images"
}
```

**Error Response (500 Internal Server Error)**:

```json
{
  "success": false,
  "images": [],
  "total_count": 0,
  "message": "Error fetching images from Storj: connection timeout"
}
```

#### Response Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `success` | boolean | Yes | Indicates if the request was successful |
| `images` | array | Yes | Array of image objects (empty array on error) |
| `total_count` | integer | Yes | Total number of images available (for pagination) |
| `message` | string | No | Human-readable status or error message |

**Image Object Fields**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filename` | string | Yes | Original filename of the image |
| `path` | string | Yes | Full path in Storj (e.g., "202501/photo_abc123.jpg") |
| `size` | integer | Yes | File size in bytes |
| `modified_time` | string | Yes | Last modified time in ISO 8601 format |
| `thumbnail_url` | string | No | URL to fetch thumbnail version (if available) |
| `url` | string | No | URL to download full-size image (if available) |

## Implementation Details

### storj_container_app Integration

The backend API should leverage the existing `storj_container_app` functionality:

1. **List files from Storj**: Use `rclone` to list files from the configured Storj bucket
   ```bash
   rclone lsf storj:bucket-name/ --format "pst" --recursive
   ```
   - `p` = path
   - `s` = size
   - `t` = modification time

2. **Filter image files**: Only return files with image extensions:
   - .jpg, .jpeg
   - .png
   - .heic
   - .webp
   - .bmp
   - .tiff

3. **Generate URLs**: Create temporary or permanent URLs for image access
   - Option 1: Use rclone's `serve http` or `serve webdav`
   - Option 2: Generate presigned URLs using Storj SDK
   - Option 3: Proxy downloads through the backend API

### Suggested Implementation Flow

```python
# In storj_uploader_backend_api_container_app/main.py

from fastapi import APIRouter, Query
from typing import Optional
import subprocess
import json

router = APIRouter()

@router.get("/storj/images")
async def get_storj_images(
    limit: Optional[int] = Query(100, ge=1, le=1000),
    offset: Optional[int] = Query(0, ge=0),
    bucket: Optional[str] = None
):
    """
    Get list of images stored in Storj
    """
    try:
        # Use configured bucket or default
        bucket_name = bucket or os.getenv("STORJ_BUCKET_NAME")
        remote_name = os.getenv("STORJ_REMOTE_NAME", "storj")

        # List files using rclone
        cmd = [
            "rclone", "lsf",
            f"{remote_name}:{bucket_name}/",
            "--format", "pst",
            "--recursive"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            return {
                "success": False,
                "images": [],
                "total_count": 0,
                "message": f"Error listing files: {result.stderr}"
            }

        # Parse output and filter images
        images = []
        image_extensions = ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.bmp', '.tiff')

        for line in result.stdout.strip().split('\n'):
            if not line:
                continue

            # Parse rclone output: path;size;time
            parts = line.split(';')
            if len(parts) != 3:
                continue

            path, size, mod_time = parts

            # Filter image files only
            if not path.lower().endswith(image_extensions):
                continue

            filename = path.split('/')[-1]

            images.append({
                "filename": filename,
                "path": path,
                "size": int(size),
                "modified_time": mod_time,
                "thumbnail_url": f"/storj/thumbnail/{path}",  # TODO: implement
                "url": f"/storj/download/{path}"  # TODO: implement
            })

        # Apply pagination
        total_count = len(images)
        paginated_images = images[offset:offset + limit]

        return {
            "success": True,
            "images": paginated_images,
            "total_count": total_count,
            "message": f"Successfully retrieved {len(paginated_images)} images"
        }

    except Exception as e:
        return {
            "success": False,
            "images": [],
            "total_count": 0,
            "message": f"Error: {str(e)}"
        }
```

## Additional Endpoints (Optional)

To fully support image display, you may also want to implement:

### GET /storj/thumbnail/{path:path}

Serve optimized thumbnail version of an image (e.g., 300x300px).

### GET /storj/download/{path:path}

Download or stream the full-size image from Storj.

## Testing

Test the endpoint using curl:

```bash
# Test basic listing
curl http://localhost:8010/storj/images

# Test pagination
curl "http://localhost:8010/storj/images?limit=10&offset=20"

# Test specific bucket
curl "http://localhost:8010/storj/images?bucket=test-bucket"
```

## Android App Integration

The Android app is already configured to call this endpoint via:

```kotlin
// In PhotoRepository.kt
suspend fun getStorjImages(
    limit: Int? = 100,
    offset: Int? = 0,
    bucket: String? = null
): Result<StorjImageListResponse>
```

Once the backend endpoint is implemented, the app can fetch and display Storj-stored images alongside local photos.

## Notes

- The endpoint should handle errors gracefully and return appropriate HTTP status codes
- Consider implementing caching to reduce repeated rclone calls
- Ensure proper authentication/authorization if needed
- The Android app expects JSON responses with the exact field names specified above
- Image URLs (thumbnail_url, url) are optional but recommended for better UX
