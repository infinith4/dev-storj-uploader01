package com.example.storjapp.model

import com.google.gson.annotations.SerializedName

data class UploadResponse(
    @SerializedName("message")
    val message: String,
    @SerializedName("results")
    val results: List<FileUploadResult>
)

data class FileUploadResult(
    @SerializedName("filename")
    val filename: String,
    @SerializedName("saved_as")
    val savedAs: String? = null,
    @SerializedName("status")
    val status: String,
    @SerializedName("message")
    val message: String,
    @SerializedName("file_info")
    val fileInfo: FileInfo? = null
)

data class FileInfo(
    @SerializedName("original_name")
    val originalName: String,
    @SerializedName("name")
    val name: String,
    @SerializedName("extension")
    val extension: String,
    @SerializedName("size_bytes")
    val sizeBytes: Long,
    @SerializedName("size_mb")
    val sizeMb: Double
)
