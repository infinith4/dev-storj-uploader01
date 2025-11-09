package com.example.storjapp.api

import com.example.storjapp.model.UploadResponse
import okhttp3.MultipartBody
import retrofit2.Response
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part

interface StorjApiService {
    @Multipart
    @POST("/upload/files")
    suspend fun uploadFiles(
        @Header("Authorization") authorization: String,
        @Part files: List<MultipartBody.Part>
    ): Response<UploadResponse>

    @Multipart
    @POST("/upload/files/single")
    suspend fun uploadSingleFile(
        @Header("Authorization") authorization: String,
        @Part file: MultipartBody.Part
    ): Response<UploadResponse>
}
