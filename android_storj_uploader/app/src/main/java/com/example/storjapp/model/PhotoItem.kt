package com.example.storjapp.model

import android.net.Uri

data class PhotoItem(
    val uri: Uri?,
    val fileName: String,
    val dateAdded: Long,
    val isUploaded: Boolean = false,
    val thumbnailPath: String? = null,
    val storjUrl: String? = null,
    val storjPath: String? = null,
    val isFromStorj: Boolean = false,
    val isVideo: Boolean = false,
    val size: Long = 0L
)
