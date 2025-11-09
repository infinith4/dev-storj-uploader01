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
     * Get all photos with upload status
     */
    suspend fun getAllPhotosWithStatus(): List<PhotoItem> = withContext(Dispatchers.IO) {
        val photos = mutableListOf<PhotoItem>()
        val uploadedPhotos = getUploadedPhotoUris()

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
            }
        }

        Log.d(TAG, "Found ${photos.size} photos (${photos.count { it.isUploaded }} uploaded)")
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
        photoUris: List<Uri>,
        bearerToken: String
    ): Result<UploadResponse> = withContext(Dispatchers.IO) {
        try {
            val parts = mutableListOf<MultipartBody.Part>()

            // Convert URIs to MultipartBody.Part
            for (uri in photoUris) {
                val file = uriToFile(uri)
                if (file != null && file.exists()) {
                    val requestBody = file.asRequestBody("image/*".toMediaTypeOrNull())
                    val part = MultipartBody.Part.createFormData(
                        "files",
                        file.name,
                        requestBody
                    )
                    parts.add(part)
                    Log.d(TAG, "Added file: ${file.name} (${file.length()} bytes)")
                }
            }

            if (parts.isEmpty()) {
                return@withContext Result.failure(Exception("No valid photos to upload"))
            }

            Log.d(TAG, "Uploading ${parts.size} photos...")
            val response = RetrofitClient.apiService.uploadFiles(
                "Bearer $bearerToken",
                parts
            )

            if (response.isSuccessful) {
                val body = response.body()
                if (body != null) {
                    Log.d(TAG, "Upload successful: ${body.message}")
                    Result.success(body)
                } else {
                    Result.failure(Exception("Empty response body"))
                }
            } else {
                val errorMsg = "Upload failed: ${response.code()} - ${response.message()}"
                Log.e(TAG, errorMsg)
                Result.failure(Exception(errorMsg))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Upload error", e)
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
}
