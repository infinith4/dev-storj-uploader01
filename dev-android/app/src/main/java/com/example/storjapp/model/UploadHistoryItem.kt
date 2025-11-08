package com.example.storjapp.model

data class UploadHistoryItem(
    val id: Long,
    val photoUri: String,
    val fileName: String,
    val uploadTime: Long,
    val status: UploadStatus,
    val thumbnailPath: String? = null
)

enum class UploadStatus {
    SUCCESS,
    FAILED,
    PENDING
}
