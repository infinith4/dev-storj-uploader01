package com.example.storjapp.worker

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.storjapp.repository.PhotoRepository

class PhotoUploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "PhotoUploadWorker"
        const val PREFS_NAME = "StorjUploaderPrefs"
        const val KEY_BEARER_TOKEN = "bearer_token"
        const val KEY_LAST_UPLOAD_TIME = "last_upload_time"
    }

    private val photoRepository = PhotoRepository(applicationContext)
    private val prefs: SharedPreferences =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override suspend fun doWork(): Result {
        Log.d(TAG, "Starting photo upload work...")

        return try {
            // Get bearer token from SharedPreferences
            val bearerToken = prefs.getString(KEY_BEARER_TOKEN, null)
            if (bearerToken.isNullOrEmpty()) {
                Log.e(TAG, "Bearer token not found")
                return Result.failure()
            }

            val currentTime = System.currentTimeMillis()

            // Get recent photos (last 24 hours)
            val recentPhotos = photoRepository.getRecentPhotos(24)

            if (recentPhotos.isEmpty()) {
                Log.d(TAG, "No recent photos to upload")
                return Result.success()
            }

            Log.d(TAG, "Found ${recentPhotos.size} recent photos to upload")

            // Upload photos in batches of 10
            val batchSize = 10
            val batches = recentPhotos.chunked(batchSize)
            var successCount = 0
            var failureCount = 0

            for ((index, batch) in batches.withIndex()) {
                Log.d(TAG, "Uploading batch ${index + 1}/${batches.size} (${batch.size} photos)")

                val result = photoRepository.uploadPhotos(batch, bearerToken)

                if (result.isSuccess) {
                    successCount += batch.size
                    Log.d(TAG, "Batch ${index + 1} uploaded successfully")
                } else {
                    failureCount += batch.size
                    Log.e(TAG, "Batch ${index + 1} upload failed: ${result.exceptionOrNull()?.message}")
                }
            }

            Log.d(TAG, "Upload completed: $successCount succeeded, $failureCount failed")

            // Update last upload time
            prefs.edit().putLong(KEY_LAST_UPLOAD_TIME, currentTime).apply()

            // Return success if at least some photos were uploaded
            if (successCount > 0) {
                Result.success()
            } else {
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during photo upload work", e)
            Result.retry()
        }
    }
}
