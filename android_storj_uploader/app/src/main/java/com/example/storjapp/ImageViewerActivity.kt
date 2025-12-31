package com.example.storjapp

import android.Manifest
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.GlideException
import com.bumptech.glide.request.RequestListener
import com.bumptech.glide.request.target.Target
import com.example.storjapp.api.RetrofitClient
import com.github.chrisbanes.photoview.PhotoView

class ImageViewerActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "ImageViewerActivity"
        const val EXTRA_IMAGE_PATH = "image_path"  // For Storj images (HTTP URL path)
        const val EXTRA_IMAGE_URI = "image_uri"    // For local images (Content URI)
        const val EXTRA_IMAGE_FILENAME = "image_filename"
        const val EXTRA_IMAGE_SIZE = "image_size"
        const val EXTRA_IMAGE_DATE = "image_date"
    }

    private lateinit var photoView: PhotoView
    private lateinit var loadingProgress: ProgressBar
    private lateinit var errorText: TextView
    private lateinit var imageTitle: TextView
    private lateinit var imageInfo: TextView
    private lateinit var downloadButton: Button
    private lateinit var closeButton: Button

    private var imagePath: String? = null  // Storj path
    private var imageUri: Uri? = null      // Local URI
    private var filename: String? = null
    private var fileSize: Long = 0
    private var modifiedDate: String? = null

    // Permission launcher for download
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            downloadImage()
        } else {
            Toast.makeText(
                this,
                "ストレージへのアクセス許可が必要です",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_image_viewer)

        // Initialize views
        photoView = findViewById(R.id.photoView)
        loadingProgress = findViewById(R.id.loadingProgress)
        errorText = findViewById(R.id.errorText)
        imageTitle = findViewById(R.id.imageTitle)
        imageInfo = findViewById(R.id.imageInfo)
        downloadButton = findViewById(R.id.downloadButton)
        closeButton = findViewById(R.id.closeButton)

        // Get image details from intent
        imagePath = intent.getStringExtra(EXTRA_IMAGE_PATH)
        val uriString = intent.getStringExtra(EXTRA_IMAGE_URI)
        imageUri = if (uriString != null) Uri.parse(uriString) else null
        filename = intent.getStringExtra(EXTRA_IMAGE_FILENAME)
        fileSize = intent.getLongExtra(EXTRA_IMAGE_SIZE, 0)
        modifiedDate = intent.getStringExtra(EXTRA_IMAGE_DATE)

        // Set title and info
        imageTitle.text = filename ?: "画像"
        imageInfo.text = formatImageInfo()

        // Setup buttons
        // Hide download button for local images (already on device)
        if (imageUri != null) {
            downloadButton.visibility = View.GONE
        } else {
            downloadButton.setOnClickListener {
                checkPermissionAndDownload()
            }
        }

        closeButton.setOnClickListener {
            finish()
        }

        // Load full-size image
        loadImage()
    }

    private fun formatImageInfo(): String {
        val sizeMB = fileSize / (1024.0 * 1024.0)
        return String.format("%.2f MB", sizeMB)
    }

    private fun loadImage() {
        // Check if this is a video file - if so, redirect to VideoPlayerActivity
        val filePathToCheck = imagePath ?: imageUri?.toString()
        if (filePathToCheck != null && isVideoFile(filePathToCheck)) {
            Log.d(TAG, "Detected video file, redirecting to VideoPlayerActivity: $filePathToCheck")
            redirectToVideoPlayer()
            return
        }

        // Determine image source: local URI or Storj URL
        val imageSource: Any = when {
            imageUri != null -> {
                Log.d(TAG, "Loading local image from URI: $imageUri")
                imageUri!!
            }
            imagePath != null -> {
                val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')
                val imageUrl = "$baseUrl/storj/images/$imagePath?thumbnail=false"
                Log.d(TAG, "Loading Storj image from URL: $imageUrl")
                imageUrl
            }
            else -> {
                showError("画像パスが指定されていません")
                return
            }
        }

        loadingProgress.visibility = View.VISIBLE
        errorText.visibility = View.GONE
        photoView.visibility = View.INVISIBLE

        Glide.with(this)
            .load(imageSource)
            .listener(object : RequestListener<android.graphics.drawable.Drawable> {
                override fun onLoadFailed(
                    e: GlideException?,
                    model: Any?,
                    target: Target<android.graphics.drawable.Drawable>,
                    isFirstResource: Boolean
                ): Boolean {
                    Log.e(TAG, "Failed to load image", e)
                    runOnUiThread {
                        showError("画像の読み込みに失敗しました")
                    }
                    return false
                }

                override fun onResourceReady(
                    resource: android.graphics.drawable.Drawable,
                    model: Any,
                    target: Target<android.graphics.drawable.Drawable>?,
                    dataSource: com.bumptech.glide.load.DataSource,
                    isFirstResource: Boolean
                ): Boolean {
                    Log.d(TAG, "Image loaded successfully")
                    runOnUiThread {
                        loadingProgress.visibility = View.GONE
                        photoView.visibility = View.VISIBLE
                    }
                    return false
                }
            })
            .into(photoView)
    }

    private fun isVideoFile(filePath: String): Boolean {
        val videoExtensions = listOf(".mp4", ".mov", ".avi", ".mkv", ".webm", ".m4v", ".3gp", ".flv", ".wmv")
        val lowerPath = filePath.lowercase()
        return videoExtensions.any { lowerPath.endsWith(it) }
    }

    private fun redirectToVideoPlayer() {
        val intent = Intent(this, VideoPlayerActivity::class.java).apply {
            if (imagePath != null) {
                putExtra(VideoPlayerActivity.EXTRA_VIDEO_PATH, imagePath)
            } else if (imageUri != null) {
                putExtra(VideoPlayerActivity.EXTRA_VIDEO_PATH, imageUri.toString())
            }
            putExtra(VideoPlayerActivity.EXTRA_VIDEO_FILENAME, filename ?: "動画")
        }
        startActivity(intent)
        finish() // Close ImageViewerActivity
    }

    private fun showError(message: String) {
        loadingProgress.visibility = View.GONE
        photoView.visibility = View.INVISIBLE
        errorText.visibility = View.VISIBLE
        errorText.text = message
    }

    private fun checkPermissionAndDownload() {
        // On Android 10+ (API 29+), we don't need WRITE_EXTERNAL_STORAGE permission
        // for downloads to the Downloads directory
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            downloadImage()
            return
        }

        // For older versions, check permission
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) == PackageManager.PERMISSION_GRANTED -> {
                downloadImage()
            }
            else -> {
                requestPermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }
    }

    private fun downloadImage() {
        if (imagePath == null || filename == null) {
            Toast.makeText(this, "画像情報が不足しています", Toast.LENGTH_SHORT).show()
            return
        }

        try {
            val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')  // Remove trailing slash
            val imageUrl = "$baseUrl/storj/images/$imagePath?thumbnail=false"

            val request = DownloadManager.Request(Uri.parse(imageUrl))
                .setTitle(filename)
                .setDescription("Storjから画像をダウンロード中...")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)

            val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            downloadManager.enqueue(request)

            Toast.makeText(
                this,
                "ダウンロードを開始しました",
                Toast.LENGTH_SHORT
            ).show()

            Log.d(TAG, "Download started for: $filename")
        } catch (e: Exception) {
            Log.e(TAG, "Download failed", e)
            Toast.makeText(
                this,
                "ダウンロードに失敗しました: ${e.message}",
                Toast.LENGTH_LONG
            ).show()
        }
    }
}
