package com.example.storjapp.repository

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import com.example.storjapp.api.RetrofitClient
import com.example.storjapp.model.PhotoItem
import com.example.storjapp.model.UploadResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.FileOutputStream

class PhotoRepository(private val context: Context) {

    companion object {
        private const val TAG = "PhotoRepository"
        private const val PREFS_NAME = "StorjUploaderPrefs"
        private const val KEY_UPLOADED_PHOTOS = "uploaded_photos"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Get all photos with upload status (local + Storj)
     */
    suspend fun getAllPhotosWithStatus(): List<PhotoItem> = withContext(Dispatchers.IO) {
        val photos = mutableListOf<PhotoItem>()
        val uploadedPhotos = getUploadedPhotoUris()
        val localFileNames = mutableSetOf<String>()

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED
        )

        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        // Get local photos
        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
            val dateColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val name = cursor.getString(nameColumn)
                val dateAdded = cursor.getLong(dateColumn)
                val uri = Uri.withAppendedPath(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id.toString()
                )

                val isUploaded = uploadedPhotos.contains(uri.toString())
                photos.add(PhotoItem(uri, name, dateAdded, isUploaded))
                localFileNames.add(name)
            }
        }

        Log.d(TAG, "Found ${photos.size} local photos (${photos.count { it.isUploaded }} uploaded)")

        // Get Storj photos
        try {
            val storjResult = getStorjImages(limit = 100, offset = 0)
            if (storjResult.isSuccess) {
                val storjResponse = storjResult.getOrNull()
                storjResponse?.images?.forEach { storjImage ->
                    // Only add if not already in local photos
                    if (!localFileNames.contains(storjImage.filename)) {
                        // Use thumbnail URL from API response, or construct if not provided
                        val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')
                        val thumbnailUrl = storjImage.thumbnailUrl
                            ?: "$baseUrl/storj/images/${storjImage.path}?thumbnail=true"

                        photos.add(
                            PhotoItem(
                                uri = null,
                                fileName = storjImage.filename,
                                dateAdded = 0L,
                                isUploaded = true,
                                thumbnailPath = null,
                                storjUrl = thumbnailUrl,
                                storjPath = storjImage.path,
                                isFromStorj = true,
                                isVideo = storjImage.isVideo
                            )
                        )
                        val mediaType = if (storjImage.isVideo) "video" else "photo"
                        Log.d(TAG, "Added Storj $mediaType: ${storjImage.filename} with thumbnail URL: $thumbnailUrl")
                    }
                }
                Log.d(TAG, "Added ${storjResponse?.images?.size ?: 0} Storj photos")
            } else {
                Log.w(TAG, "Failed to fetch Storj photos: ${storjResult.exceptionOrNull()?.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching Storj photos", e)
        }

        Log.d(TAG, "Total photos: ${photos.size}")
        photos
    }

    /**
     * Get all photos from device
     */
    suspend fun getAllPhotos(): List<Uri> = withContext(Dispatchers.IO) {
        val photos = mutableListOf<Uri>()
        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED
        )

        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val uri = Uri.withAppendedPath(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id.toString()
                )
                photos.add(uri)
            }
        }

        Log.d(TAG, "Found ${photos.size} photos")
        photos
    }

    /**
     * Get recently added photos (last 24 hours)
     */
    suspend fun getRecentPhotos(hoursAgo: Int = 24): List<Uri> = withContext(Dispatchers.IO) {
        val photos = mutableListOf<Uri>()
        val currentTime = System.currentTimeMillis() / 1000
        val timeThreshold = currentTime - (hoursAgo * 60 * 60)

        val projection = arrayOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED
        )

        val selection = "${MediaStore.Images.Media.DATE_ADDED} >= ?"
        val selectionArgs = arrayOf(timeThreshold.toString())
        val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

        context.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val uri = Uri.withAppendedPath(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    id.toString()
                )
                photos.add(uri)
            }
        }

        Log.d(TAG, "Found ${photos.size} recent photos (last $hoursAgo hours)")
        photos
    }

    /**
     * Upload photos to Storj backend API
     */
    suspend fun uploadPhotos(
        photoUris: List<Uri>
    ): Result<UploadResponse> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "=== Starting upload process ===")
            Log.d(TAG, "Photo URIs to upload: ${photoUris.size}")

            val parts = mutableListOf<MultipartBody.Part>()

            // Convert URIs to MultipartBody.Part
            for ((index, uri) in photoUris.withIndex()) {
                Log.d(TAG, "Processing photo ${index + 1}/${photoUris.size}: $uri")
                val file = uriToFile(uri)
                if (file != null && file.exists()) {
                    val requestBody = file.asRequestBody("image/*".toMediaTypeOrNull())
                    val part = MultipartBody.Part.createFormData(
                        "files",
                        file.name,
                        requestBody
                    )
                    parts.add(part)
                    Log.d(TAG, "✓ Added file: ${file.name} (${file.length()} bytes)")
                } else {
                    Log.w(TAG, "✗ Failed to convert URI to file: $uri")
                }
            }

            if (parts.isEmpty()) {
                Log.e(TAG, "No valid photos to upload after conversion")
                return@withContext Result.failure(Exception("No valid photos to upload"))
            }

            Log.d(TAG, "--- Sending HTTP request ---")
            Log.d(TAG, "Endpoint: POST /upload/files")
            Log.d(TAG, "Files count: ${parts.size}")
            Log.d(TAG, "Request started at: ${System.currentTimeMillis()}")

            val response = RetrofitClient.apiService.uploadFiles(
                parts
            )

            Log.d(TAG, "--- HTTP response received ---")
            Log.d(TAG, "Response code: ${response.code()}")
            Log.d(TAG, "Response message: ${response.message()}")
            Log.d(TAG, "Is successful: ${response.isSuccessful}")

            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    Log.d(TAG, "✓ Upload successful!")
                    Log.d(TAG, "Response message: ${body.message}")
                    Log.d(TAG, "Files processed: ${body.results.size}")
                    body.results.forEachIndexed { index, result ->
                        Log.d(TAG, "  File ${index + 1}: ${result.filename}")
                        Log.d(TAG, "    Status: ${result.status}")
                        Log.d(TAG, "    Message: ${result.message}")
                        if (result.savedAs != null) {
                            Log.d(TAG, "    Saved as: ${result.savedAs}")
                        }
                    }
                    Log.d(TAG, "=== Upload process completed successfully ===")
                    Result.success(body)
                } else {
                    Log.e(TAG, "✗ Empty response body")
                    Log.d(TAG, "=== Upload process failed ===")
                    Result.failure(Exception("Empty response body"))
                }
            } else {
                val errorBody = response.errorBody()?.string()
                val errorMsg = "Upload failed: ${response.code()} - ${response.message()}"
                Log.e(TAG, "✗ $errorMsg")
                Log.e(TAG, "Error body: $errorBody")
                Log.d(TAG, "=== Upload process failed ===")
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗ Upload exception occurred", e)
            Log.e(TAG, "Exception type: ${e.javaClass.simpleName}")
            Log.e(TAG, "Exception message: ${e.message}")
            Log.d(TAG, "=== Upload process failed with exception ===")
            Result.failure(e)
        }
    }

    /**
     * Convert URI to File
     */
    private fun uriToFile(uri: Uri): File? {
        return try {
            val contentResolver: ContentResolver = context.contentResolver
            val displayName = getFileName(uri) ?: "photo_${System.currentTimeMillis()}.jpg"
            val file = File(context.cacheDir, displayName)

            contentResolver.openInputStream(uri)?.use { inputStream ->
                FileOutputStream(file).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }

            file
        } catch (e: Exception) {
            Log.e(TAG, "Error converting URI to file", e)
            null
        }
    }

    /**
     * Get file name from URI
     */
    private fun getFileName(uri: Uri): String? {
        var fileName: String? = null
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
            if (nameIndex != -1 && cursor.moveToFirst()) {
                fileName = cursor.getString(nameIndex)
            }
        }
        return fileName
    }

    /**
     * Get uploaded photo URIs from SharedPreferences
     */
    private fun getUploadedPhotoUris(): Set<String> {
        val uploadedJson = prefs.getString(KEY_UPLOADED_PHOTOS, null)
        return if (uploadedJson != null) {
            uploadedJson.split(",").toSet()
        } else {
            emptySet()
        }
    }

    /**
     * Mark photos as uploaded
     */
    fun markPhotosAsUploaded(photoUris: List<Uri>) {
        val currentUploaded = getUploadedPhotoUris().toMutableSet()
        photoUris.forEach { uri ->
            currentUploaded.add(uri.toString())
        }
        prefs.edit().putString(KEY_UPLOADED_PHOTOS, currentUploaded.joinToString(",")).apply()
        Log.d(TAG, "Marked ${photoUris.size} photos as uploaded")
    }

    /**
     * Check API health
     */
    suspend fun checkApiHealth(): Result<Boolean> = withContext(Dispatchers.IO) {
        try {
            val response = RetrofitClient.apiService.healthCheck()
            if (response.isSuccessful) {
                Log.d(TAG, "API health check: OK")
                Result.success(true)
            } else {
                Log.w(TAG, "API health check failed: ${response.code()}")
                Result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "API health check error", e)
            Result.success(false)
        }
    }

    /**
     * Get list of images stored in Storj
     * @param limit Maximum number of images to return
     * @param offset Offset for pagination
     * @param bucket Specific bucket name (optional)
     */
    suspend fun getStorjImages(
        limit: Int? = 100,
        offset: Int? = 0,
        bucket: String? = null
    ): Result<com.example.storjapp.model.StorjImageListResponse> = withContext(Dispatchers.IO) {
        try {
            Log.d(TAG, "Fetching Storj images (limit: $limit, offset: $offset)")
            val response = RetrofitClient.apiService.getStorjImages(limit, offset, bucket)

            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    Log.d(TAG, "✓ Fetched ${body.images.size} images from Storj")
                    Result.success(body)
                } else {
                    Log.e(TAG, "✗ Response body is null")
                    Result.failure(Exception("Response body is null"))
                }
            } else {
                Log.e(TAG, "✗ Failed to fetch Storj images: ${response.code()}")
                Result.failure(Exception("API error: ${response.code()} - ${response.message()}"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error fetching Storj images", e)
            Result.failure(e)
        }
    }
}
