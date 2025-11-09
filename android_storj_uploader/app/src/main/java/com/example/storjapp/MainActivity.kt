package com.example.storjapp

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import androidx.work.*
import androidx.work.OneTimeWorkRequestBuilder
import com.example.storjapp.adapter.UploadHistoryAdapter
import com.example.storjapp.model.UploadHistoryItem
import com.example.storjapp.model.UploadStatus
import com.example.storjapp.repository.PhotoRepository
import com.example.storjapp.worker.PhotoUploadWorker
import com.google.android.material.textfield.TextInputEditText
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val PREFS_NAME = "StorjUploaderPrefs"
        private const val KEY_BEARER_TOKEN = "bearer_token"
        private const val KEY_UPLOAD_HISTORY = "upload_history"
    }

    private lateinit var tokenInput: TextInputEditText
    private lateinit var saveTokenButton: Button
    private lateinit var uploadNowButton: Button
    private lateinit var statusText: TextView
    private lateinit var uploadProgressBar: ProgressBar
    private lateinit var progressText: TextView
    private lateinit var uploadHistoryRecyclerView: RecyclerView
    private lateinit var swipeRefreshLayout: SwipeRefreshLayout
    private lateinit var prefs: SharedPreferences
    private lateinit var photoRepository: PhotoRepository
    private lateinit var historyAdapter: UploadHistoryAdapter
    private val gson = Gson()
    private var permissionChecked = false

    // Permission launcher
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
        if (isGranted) {
            Log.d(TAG, "Permission granted")
            updateStatus("Permission granted")
            setupAutoUpload()
        } else {
            Log.e(TAG, "Permission denied")
            updateStatus("Permission denied - Cannot access photos")
            Toast.makeText(
                this,
                "Photo access permission is required for auto-upload",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize views
        tokenInput = findViewById(R.id.tokenInput)
        saveTokenButton = findViewById(R.id.saveTokenButton)
        uploadNowButton = findViewById(R.id.uploadNowButton)
        statusText = findViewById(R.id.statusText)
        uploadProgressBar = findViewById(R.id.uploadProgressBar)
        progressText = findViewById(R.id.progressText)
        uploadHistoryRecyclerView = findViewById(R.id.uploadHistoryRecyclerView)
        swipeRefreshLayout = findViewById(R.id.swipeRefreshLayout)

        // Set title with commit version (with error handling)
        try {
            val appTitle = "Storj Photo Uploader (${BuildConfig.GIT_COMMIT_HASH})"
            val titleText = findViewById<TextView>(R.id.titleText)
            titleText.text = appTitle
            supportActionBar?.title = appTitle
        } catch (e: Exception) {
            Log.e(TAG, "Error setting title", e)
            val titleText = findViewById<TextView>(R.id.titleText)
            titleText.text = "Storj Photo Uploader"
            supportActionBar?.title = "Storj Photo Uploader"
        }

        // Initialize SharedPreferences
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Initialize repository
        photoRepository = PhotoRepository(this)

        // Setup RecyclerView
        historyAdapter = UploadHistoryAdapter()
        uploadHistoryRecyclerView.apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = historyAdapter
        }

        // Load upload history asynchronously
        lifecycleScope.launch {
            loadUploadHistory()
        }

        // Setup SwipeRefreshLayout
        swipeRefreshLayout.setOnRefreshListener {
            lifecycleScope.launch {
                loadUploadHistory()
                swipeRefreshLayout.isRefreshing = false
            }
        }

        // Load saved token
        val savedToken = prefs.getString(KEY_BEARER_TOKEN, "")
        if (!savedToken.isNullOrEmpty()) {
            tokenInput.setText(savedToken)
            uploadNowButton.isEnabled = true
            updateStatus("Token configured")
        } else {
            updateStatus("Please configure Bearer Token")
        }

        // Setup button listeners
        saveTokenButton.setOnClickListener {
            saveToken()
        }

        uploadNowButton.setOnClickListener {
            uploadPhotosManually()
        }
    }

    override fun onResume() {
        super.onResume()
        // Check and request permission only once on first resume
        if (!permissionChecked) {
            permissionChecked = true
            checkAndRequestPermission()
        }
    }

    private fun saveToken() {
        val token = tokenInput.text.toString().trim()
        if (token.isEmpty()) {
            Toast.makeText(this, "Please enter a Bearer Token", Toast.LENGTH_SHORT).show()
            return
        }

        prefs.edit().putString(KEY_BEARER_TOKEN, token).apply()
        uploadNowButton.isEnabled = true
        updateStatus("Token saved")
        Toast.makeText(this, "Token saved successfully", Toast.LENGTH_SHORT).show()

        // Setup auto-upload after saving token
        setupAutoUpload()
    }

    private fun checkAndRequestPermission() {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }

        when {
            ContextCompat.checkSelfPermission(
                this,
                permission
            ) == PackageManager.PERMISSION_GRANTED -> {
                Log.d(TAG, "Permission already granted")
                updateStatus("Ready - Auto-upload active")
                setupAutoUpload()
            }
            else -> {
                requestPermissionLauncher.launch(permission)
            }
        }
    }

    private fun setupAutoUpload() {
        val token = prefs.getString(KEY_BEARER_TOKEN, null)
        if (token.isNullOrEmpty()) {
            Log.w(TAG, "Cannot setup auto-upload: No bearer token configured")
            return
        }

        // Create periodic work request (runs every 15 minutes)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val uploadWorkRequest = PeriodicWorkRequestBuilder<PhotoUploadWorker>(
            15, TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.LINEAR,
                WorkRequest.MIN_BACKOFF_MILLIS,
                TimeUnit.MILLISECONDS
            )
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "PhotoUploadWork",
            ExistingPeriodicWorkPolicy.KEEP,
            uploadWorkRequest
        )

        // Schedule an immediate one-time upload to test the setup
        val immediateUploadRequest = OneTimeWorkRequestBuilder<PhotoUploadWorker>()
            .setConstraints(constraints)
            .setInitialDelay(30, TimeUnit.SECONDS) // 30 seconds after setup
            .build()

        WorkManager.getInstance(this).enqueue(immediateUploadRequest)

        Log.d(TAG, "Auto-upload scheduled (periodic + immediate)")
        updateStatus("Auto-upload active (every 15 min)")
    }

    private fun uploadPhotosManually() {
        val token = prefs.getString(KEY_BEARER_TOKEN, null)
        if (token.isNullOrEmpty()) {
            Toast.makeText(this, "Please save Bearer Token first", Toast.LENGTH_SHORT).show()
            return
        }

        uploadNowButton.isEnabled = false
        updateStatus("Uploading photos...")
        showProgress(true)

        lifecycleScope.launch {
            try {
                val recentPhotos = photoRepository.getRecentPhotos(24)

                if (recentPhotos.isEmpty()) {
                    updateStatus("No recent photos to upload")
                    Toast.makeText(
                        this@MainActivity,
                        "No photos found from last 24 hours",
                        Toast.LENGTH_SHORT
                    ).show()
                    uploadNowButton.isEnabled = true
                    showProgress(false)
                    return@launch
                }

                // Update progress
                val totalPhotos = recentPhotos.size
                updateProgressText(0, totalPhotos)

                // Upload photos in batches
                val batchSize = 5
                val batches = recentPhotos.chunked(batchSize)
                var uploadedCount = 0

                for ((index, batch) in batches.withIndex()) {
                    val result = photoRepository.uploadPhotos(batch, token)

                    if (result.isSuccess) {
                        // Add to history
                        batch.forEach { uri ->
                            val fileName = uri.lastPathSegment ?: "unknown.jpg"
                            val historyItem = UploadHistoryItem(
                                id = System.currentTimeMillis(),
                                photoUri = uri.toString(),
                                fileName = fileName,
                                uploadTime = System.currentTimeMillis(),
                                status = UploadStatus.SUCCESS
                            )
                            addToUploadHistory(historyItem)
                        }
                        uploadedCount += batch.size
                    } else {
                        // Mark as failed in history
                        batch.forEach { uri ->
                            val fileName = uri.lastPathSegment ?: "unknown.jpg"
                            val historyItem = UploadHistoryItem(
                                id = System.currentTimeMillis(),
                                photoUri = uri.toString(),
                                fileName = fileName,
                                uploadTime = System.currentTimeMillis(),
                                status = UploadStatus.FAILED
                            )
                            addToUploadHistory(historyItem)
                        }
                    }

                    // Update progress
                    val progress = ((index + 1) * 100) / batches.size
                    updateProgressBar(progress)
                    updateProgressText(uploadedCount, totalPhotos)
                }

                if (uploadedCount > 0) {
                    updateStatus("Upload successful: $uploadedCount photos uploaded")
                    Toast.makeText(
                        this@MainActivity,
                        "Uploaded $uploadedCount of $totalPhotos photos",
                        Toast.LENGTH_SHORT
                    ).show()
                } else {
                    updateStatus("Upload failed")
                    Toast.makeText(
                        this@MainActivity,
                        "Upload failed",
                        Toast.LENGTH_LONG
                    ).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Upload error", e)
                updateStatus("Error: ${e.message}")
                Toast.makeText(
                    this@MainActivity,
                    "Error: ${e.message}",
                    Toast.LENGTH_LONG
                ).show()
            } finally {
                uploadNowButton.isEnabled = true
                showProgress(false)
            }
        }
    }

    private fun updateStatus(status: String) {
        statusText.text = "Status: $status"
        Log.d(TAG, "Status: $status")
    }

    private fun showProgress(show: Boolean) {
        uploadProgressBar.visibility = if (show) View.VISIBLE else View.GONE
        progressText.visibility = if (show) View.VISIBLE else View.GONE
        if (!show) {
            uploadProgressBar.progress = 0
        }
    }

    private fun updateProgressBar(progress: Int) {
        uploadProgressBar.progress = progress
    }

    private fun updateProgressText(uploaded: Int, total: Int) {
        progressText.text = "$uploaded / $total photos uploaded"
    }

    private fun loadUploadHistory() {
        val historyJson = prefs.getString(KEY_UPLOAD_HISTORY, null)
        if (historyJson != null) {
            try {
                val type = object : TypeToken<List<UploadHistoryItem>>() {}.type
                val history: List<UploadHistoryItem> = gson.fromJson(historyJson, type)
                historyAdapter.updateItems(history)
            } catch (e: Exception) {
                Log.e(TAG, "Error loading upload history", e)
            }
        }
    }

    private fun saveUploadHistory(history: List<UploadHistoryItem>) {
        try {
            val historyJson = gson.toJson(history)
            prefs.edit().putString(KEY_UPLOAD_HISTORY, historyJson).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving upload history", e)
        }
    }

    private fun addToUploadHistory(item: UploadHistoryItem) {
        // Load current history
        val historyJson = prefs.getString(KEY_UPLOAD_HISTORY, null)
        val history = if (historyJson != null) {
            try {
                val type = object : TypeToken<MutableList<UploadHistoryItem>>() {}.type
                gson.fromJson<MutableList<UploadHistoryItem>>(historyJson, type)
            } catch (e: Exception) {
                mutableListOf()
            }
        } else {
            mutableListOf()
        }

        // Add new item at beginning
        history.add(0, item)

        // Keep only last 100 items
        if (history.size > 100) {
            history.subList(100, history.size).clear()
        }

        // Save and update UI
        saveUploadHistory(history)
        historyAdapter.addItem(item)
    }
}
