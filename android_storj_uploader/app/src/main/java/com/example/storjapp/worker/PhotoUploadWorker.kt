package com.example.storjapp.worker

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.storjapp.config.UploadConfig
import com.example.storjapp.repository.PhotoRepository

class PhotoUploadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "PhotoUploadWorker"
        const val PREFS_NAME = "StorjUploaderPrefs"
        const val KEY_LAST_UPLOAD_TIME = "last_upload_time"
    }

    private val photoRepository = PhotoRepository(applicationContext)
    private val prefs: SharedPreferences =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override suspend fun doWork(): Result {
        Log.d(TAG, "Starting media upload work...")

        return try {
            val currentTime = System.currentTimeMillis()

            // Check upload limits before proceeding
            val (isWithinLimit, pendingImages, pendingVideos) = photoRepository.checkUploadLimits()

            if (!isWithinLimit) {
                Log.w(TAG, "Upload limits exceeded: images=$pendingImages/${UploadConfig.MAX_IMAGE_UPLOAD_LIMIT}, " +
                        "videos=$pendingVideos/${UploadConfig.MAX_VIDEO_UPLOAD_LIMIT}")
                // Still return success to avoid retrying when limits are exceeded
                return Result.success()
            }

            // Get recent media files (photos and videos, last 24 hours)
            val recentPhotos = photoRepository.getRecentPhotos(UploadConfig.RECENT_MEDIA_HOURS)

            if (recentPhotos.isEmpty()) {
                Log.d(TAG, "No recent media files to upload")
                return Result.success()
            }

            Log.d(TAG, "Found ${recentPhotos.size} recent media files to upload")

            // Filter by upload limits (respects quota for images and videos separately)
            val filteredPhotos = photoRepository.filterByUploadLimits(recentPhotos)

            if (filteredPhotos.isEmpty()) {
                Log.d(TAG, "No media files within upload limits")
                return Result.success()
            }

            Log.d(TAG, "Uploading ${filteredPhotos.size} media files (within upload limits)")

            // Upload media files in batches
            val batchSize = UploadConfig.UPLOAD_BATCH_SIZE
            val batches = filteredPhotos.chunked(batchSize)
            var successCount = 0
            var failureCount = 0
            var skippedCount = recentPhotos.size - filteredPhotos.size

            for ((index, batch) in batches.withIndex()) {
                Log.d(TAG, "Uploading batch ${index + 1}/${batches.size} (${batch.size} media files)")

                val result = photoRepository.uploadPhotos(batch)

                if (result.isSuccess) {
                    // Mark media files as uploaded
                    photoRepository.markPhotosAsUploaded(batch)
                    successCount += batch.size
                    Log.d(TAG, "Batch ${index + 1} uploaded successfully")
                } else {
                    failureCount += batch.size
                    Log.e(TAG, "Batch ${index + 1} upload failed: ${result.exceptionOrNull()?.message}")
                }
            }

            Log.d(TAG, "Upload completed: $successCount succeeded, $failureCount failed, $skippedCount skipped (quota)")

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
