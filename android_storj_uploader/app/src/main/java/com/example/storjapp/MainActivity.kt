package com.example.storjapp

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.MenuItem
import android.widget.Button
import android.widget.PopupMenu
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout
import androidx.work.*
import androidx.work.OneTimeWorkRequestBuilder
import com.example.storjapp.adapter.PhotoGridAdapter
import com.example.storjapp.config.UploadConfig
import com.example.storjapp.repository.PhotoRepository
import com.example.storjapp.worker.PhotoUploadWorker
import kotlinx.coroutines.launch
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val PREFS_NAME = "StorjUploaderPrefs"
    }

    private lateinit var settingsButton: Button
    private lateinit var statusText: TextView
    private lateinit var healthCheckText: TextView
    private lateinit var uploadQuotaText: TextView
    private lateinit var photoGridRecyclerView: RecyclerView
    private lateinit var swipeRefreshLayout: SwipeRefreshLayout
    private lateinit var prefs: SharedPreferences
    private lateinit var photoRepository: PhotoRepository
    private lateinit var gridAdapter: PhotoGridAdapter
    private var permissionChecked = false
    private var healthCheckJob: kotlinx.coroutines.Job? = null
    private var quotaCheckJob: kotlinx.coroutines.Job? = null

    // Permission launcher for multiple permissions
    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val allGranted = permissions.values.all { it }
        if (allGranted) {
            Log.d(TAG, "All permissions granted")
            updateStatus("Permissions granted")
            setupAutoUpload()
        } else {
            val deniedPermissions = permissions.filterValues { !it }.keys
            Log.e(TAG, "Permissions denied: $deniedPermissions")
            updateStatus("Permission denied - Cannot access media")
            Toast.makeText(
                this,
                "Photo and video access permissions are required for auto-upload",
                Toast.LENGTH_LONG
            ).show()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Initialize views
        settingsButton = findViewById(R.id.settingsButton)
        statusText = findViewById(R.id.statusText)
        healthCheckText = findViewById(R.id.healthCheckText)
        uploadQuotaText = findViewById(R.id.uploadQuotaText)
        photoGridRecyclerView = findViewById(R.id.photoGridRecyclerView)
        swipeRefreshLayout = findViewById(R.id.swipeRefreshLayout)

        // Set title with commit version (with error handling)
        try {
            val appTitle = "Storj Photo Uploader (${BuildConfig.GIT_COMMIT_HASH})"
            val titleText = findViewById<TextView>(R.id.titleText)
            titleText.text = appTitle
        } catch (e: Exception) {
            Log.e(TAG, "Error setting title", e)
            val titleText = findViewById<TextView>(R.id.titleText)
            titleText.text = "Storj Photo Uploader"
        }

        // Initialize SharedPreferences
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Initialize repository
        photoRepository = PhotoRepository(this)

        // Setup RecyclerView with GridLayoutManager (3 columns)
        gridAdapter = PhotoGridAdapter()
        photoGridRecyclerView.apply {
            layoutManager = GridLayoutManager(this@MainActivity, 3)
            adapter = gridAdapter
        }

        // Load all photos asynchronously
        lifecycleScope.launch {
            loadAllPhotos()
        }

        // Setup SwipeRefreshLayout
        swipeRefreshLayout.setOnRefreshListener {
            lifecycleScope.launch {
                loadAllPhotos()
                swipeRefreshLayout.isRefreshing = false
            }
        }

        updateStatus("Ready")

        // Setup settings button listener with popup menu
        settingsButton.setOnClickListener { view ->
            showMainMenu(view)
        }

        // Start periodic health check
        startHealthCheck()

        // Start periodic upload quota check
        startUploadQuotaCheck()
    }

    override fun onResume() {
        super.onResume()
        // Check and request permission only once on first resume
        if (!permissionChecked) {
            permissionChecked = true
            checkAndRequestPermission()
        }

        // Reload photos when returning from settings (in case upload status changed)
        lifecycleScope.launch {
            loadAllPhotos()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cancel background jobs
        healthCheckJob?.cancel()
        quotaCheckJob?.cancel()
    }


    private fun checkAndRequestPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ requires separate permissions for images and videos
            val imagePermission = Manifest.permission.READ_MEDIA_IMAGES
            val videoPermission = Manifest.permission.READ_MEDIA_VIDEO

            val imageGranted = ContextCompat.checkSelfPermission(this, imagePermission) == PackageManager.PERMISSION_GRANTED
            val videoGranted = ContextCompat.checkSelfPermission(this, videoPermission) == PackageManager.PERMISSION_GRANTED

            when {
                imageGranted && videoGranted -> {
                    Log.d(TAG, "Both image and video permissions already granted")
                    updateStatus("Ready - Auto-upload active")
                    setupAutoUpload()
                }
                else -> {
                    // Request both permissions
                    val permissionsToRequest = mutableListOf<String>()
                    if (!imageGranted) permissionsToRequest.add(imagePermission)
                    if (!videoGranted) permissionsToRequest.add(videoPermission)

                    Log.d(TAG, "Requesting permissions: $permissionsToRequest")
                    requestPermissionLauncher.launch(permissionsToRequest.toTypedArray())
                }
            }
        } else {
            // Android 12 and below
            val permission = Manifest.permission.READ_EXTERNAL_STORAGE
            when {
                ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED -> {
                    Log.d(TAG, "Storage permission already granted")
                    updateStatus("Ready - Auto-upload active")
                    setupAutoUpload()
                }
                else -> {
                    Log.d(TAG, "Requesting permission: $permission")
                    requestPermissionLauncher.launch(arrayOf(permission))
                }
            }
        }
    }

    private fun setupAutoUpload() {
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

    private fun updateStatus(status: String) {
        statusText.text = "Status: $status"
        Log.d(TAG, "Status: $status")
    }

    private suspend fun loadAllPhotos() {
        try {
            val photos = photoRepository.getAllPhotosWithStatus()
            gridAdapter.updateItems(photos)
            Log.d(TAG, "Loaded ${photos.size} photos")
        } catch (e: Exception) {
            Log.e(TAG, "Error loading photos", e)
        }
    }

    private fun startHealthCheck() {
        healthCheckJob?.cancel()
        healthCheckJob = lifecycleScope.launch {
            while (true) {
                performHealthCheck()
                kotlinx.coroutines.delay(30000) // 30 seconds
            }
        }
    }

    private suspend fun performHealthCheck() {
        val result = photoRepository.checkApiHealth()
        val isHealthy = result.getOrDefault(false)

        updateHealthCheckUI(isHealthy)
    }

    private fun updateHealthCheckUI(isHealthy: Boolean) {
        if (isHealthy) {
            healthCheckText.text = "API: Connected ✓"
            healthCheckText.setTextColor(getColor(android.R.color.holo_green_dark))
        } else {
            healthCheckText.text = "API: Disconnected ✗"
            healthCheckText.setTextColor(getColor(android.R.color.holo_red_dark))
        }
    }

    private fun showMainMenu(view: android.view.View) {
        val popupMenu = PopupMenu(this, view)
        popupMenu.menuInflater.inflate(R.menu.main_menu, popupMenu.menu)

        popupMenu.setOnMenuItemClickListener { menuItem: MenuItem ->
            when (menuItem.itemId) {
                R.id.menu_upload_list -> {
                    val intent = Intent(this, SettingsActivity::class.java)
                    startActivity(intent)
                    true
                }
                else -> false
            }
        }

        popupMenu.show()
    }

    private fun startUploadQuotaCheck() {
        quotaCheckJob?.cancel()
        quotaCheckJob = lifecycleScope.launch {
            while (true) {
                performUploadQuotaCheck()
                kotlinx.coroutines.delay(30000) // 30 seconds
            }
        }
    }

    private suspend fun performUploadQuotaCheck() {
        try {
            val (isWithinLimit, pendingImages, pendingVideos) = photoRepository.checkUploadLimits()
            updateUploadQuotaUI(isWithinLimit, pendingImages, pendingVideos)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking upload quota", e)
        }
    }

    private fun updateUploadQuotaUI(isWithinLimit: Boolean, pendingImages: Int, pendingVideos: Int) {
        val quotaText = "Upload Queue: $pendingImages/${UploadConfig.MAX_IMAGE_UPLOAD_LIMIT} images, " +
                "$pendingVideos/${UploadConfig.MAX_VIDEO_UPLOAD_LIMIT} videos"

        uploadQuotaText.text = quotaText

        if (!isWithinLimit) {
            uploadQuotaText.setTextColor(getColor(android.R.color.holo_red_dark))
            Toast.makeText(
                this,
                "Upload limit exceeded! Images: $pendingImages/${UploadConfig.MAX_IMAGE_UPLOAD_LIMIT}, " +
                        "Videos: $pendingVideos/${UploadConfig.MAX_VIDEO_UPLOAD_LIMIT}",
                Toast.LENGTH_LONG
            ).show()
        } else if (pendingImages > UploadConfig.MAX_IMAGE_UPLOAD_LIMIT * 0.8 ||
                   pendingVideos > UploadConfig.MAX_VIDEO_UPLOAD_LIMIT * 0.8) {
            // Warning when approaching limit (>80%)
            uploadQuotaText.setTextColor(getColor(android.R.color.holo_orange_dark))
        } else {
            uploadQuotaText.setTextColor(getColor(android.R.color.darker_gray))
        }
    }
}
