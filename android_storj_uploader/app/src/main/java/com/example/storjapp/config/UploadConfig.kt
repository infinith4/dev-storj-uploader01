package com.example.storjapp.config

/**
 * Configuration constants for upload limits and batch processing
 */
object UploadConfig {
    /**
     * Maximum number of images allowed in upload queue
     */
    const val MAX_IMAGE_UPLOAD_LIMIT = 1000

    /**
     * Maximum number of videos allowed in upload queue
     */
    const val MAX_VIDEO_UPLOAD_LIMIT = 100

    /**
     * Batch size for parallel uploads
     */
    const val UPLOAD_BATCH_SIZE = 10

    /**
     * Time window in hours for recent media detection
     */
    const val RECENT_MEDIA_HOURS = 24
}
