package com.example.storjapp.model

import com.google.gson.annotations.SerializedName

/**
 * Represents an image or video stored in Storj cloud storage
 */
data class StorjImageItem(
    @SerializedName("filename")
    val filename: String,

    @SerializedName("path")
    val path: String,

    @SerializedName("size")
    val size: Long,

    @SerializedName("modified_time")
    val modifiedTime: String,

    @SerializedName("thumbnail_url")
    val thumbnailUrl: String? = null,

    @SerializedName("url")
    val url: String? = null,

    @SerializedName("is_video")
    val isVideo: Boolean = false
)

/**
 * Response for listing images from Storj
 */
data class StorjImageListResponse(
    @SerializedName("success")
    val success: Boolean,

    @SerializedName("images")
    val images: List<StorjImageItem>,

    @SerializedName("total_count")
    val totalCount: Int,

    @SerializedName("message")
    val message: String? = null
)
