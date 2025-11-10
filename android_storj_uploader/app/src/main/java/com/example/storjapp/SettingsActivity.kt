package com.example.storjapp

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.example.storjapp.repository.PhotoRepository
import kotlinx.coroutines.launch

class SettingsActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "SettingsActivity"
    }

    private lateinit var uploadNowButton: Button
    private lateinit var statusText: TextView
    private lateinit var uploadProgressBar: ProgressBar
    private lateinit var progressText: TextView
    private lateinit var photoRepository: PhotoRepository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_settings)

        // Set title
        title = "Settings"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        // Initialize views
        uploadNowButton = findViewById(R.id.uploadNowButton)
        statusText = findViewById(R.id.statusText)
        uploadProgressBar = findViewById(R.id.uploadProgressBar)
        progressText = findViewById(R.id.progressText)

        // Initialize repository
        photoRepository = PhotoRepository(this)

        // Setup upload button
        uploadNowButton.setOnClickListener {
            uploadPhotosManually()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun uploadPhotosManually() {
        uploadNowButton.isEnabled = false
        updateStatus("Uploading photos...")
        showProgress(true)

        lifecycleScope.launch {
            try {
                val recentPhotos = photoRepository.getRecentPhotos(24)

                if (recentPhotos.isEmpty()) {
                    updateStatus("No recent photos to upload")
                    Toast.makeText(
                        this@SettingsActivity,
                        "No photos found from last 24 hours",
                        Toast.LENGTH_SHORT
                    ).show()
                    uploadNowButton.isEnabled = true
                    showProgress(false)
                    return@launch
                }

                val totalPhotos = recentPhotos.size
                updateProgressText(0, totalPhotos)

                val batchSize = 5
                val batches = recentPhotos.chunked(batchSize)
                var uploadedCount = 0

                for ((index, batch) in batches.withIndex()) {
                    val result = photoRepository.uploadPhotos(batch)

                    if (result.isSuccess) {
                        photoRepository.markPhotosAsUploaded(batch)
                        uploadedCount += batch.size
                    }

                    val progress = ((index + 1) * 100) / batches.size
                    updateProgressBar(progress)
                    updateProgressText(uploadedCount, totalPhotos)
                }

                if (uploadedCount > 0) {
                    updateStatus("Upload successful: $uploadedCount photos uploaded")
                    Toast.makeText(
                        this@SettingsActivity,
                        "Uploaded $uploadedCount of $totalPhotos photos",
                        Toast.LENGTH_SHORT
                    ).show()
                } else {
                    updateStatus("Upload failed")
                    Toast.makeText(
                        this@SettingsActivity,
                        "Upload failed",
                        Toast.LENGTH_LONG
                    ).show()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Upload error", e)
                updateStatus("Error: ${e.message}")
                Toast.makeText(
                    this@SettingsActivity,
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
}
