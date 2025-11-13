package com.example.storjapp.api

import com.example.storjapp.model.StorjImageListResponse
import com.example.storjapp.model.UploadResponse
import okhttp3.MultipartBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Query

interface StorjApiService {
    @GET("/health")
    suspend fun healthCheck(): Response<ResponseBody>

    @Multipart
    @POST("/upload/files")
    suspend fun uploadFiles(
        @Part files: List<MultipartBody.Part>
    ): Response<UploadResponse>

    @Multipart
    @POST("/upload/files/single")
    suspend fun uploadSingleFile(
        @Header("Authorization") authorization: String,
        @Part file: MultipartBody.Part
    ): Response<UploadResponse>

    /**
     * Get list of images stored in Storj
     * @param limit Maximum number of images to return (optional)
     * @param offset Offset for pagination (optional)
     * @param bucket Specific bucket name (optional, uses default if not provided)
     */
    @GET("/storj/images")
    suspend fun getStorjImages(
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null,
        @Query("bucket") bucket: String? = null
    ): Response<StorjImageListResponse>
}
