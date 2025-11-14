package com.example.storjapp

import android.os.Bundle
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.example.storjapp.api.RetrofitClient

class VideoPlayerActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "VideoPlayerActivity"
        const val EXTRA_VIDEO_PATH = "video_path"
        const val EXTRA_VIDEO_FILENAME = "video_filename"
    }

    private lateinit var playerView: PlayerView
    private lateinit var loadingProgress: ProgressBar
    private lateinit var errorText: TextView
    private lateinit var closeButton: ImageButton
    private lateinit var titleText: TextView

    private var player: ExoPlayer? = null
    private var videoPath: String? = null
    private var videoFilename: String? = null
    private var playWhenReady = true
    private var currentPosition = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // フルスクリーン設定
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        supportActionBar?.hide()

        setContentView(R.layout.activity_video_player)

        // Get extras
        videoPath = intent.getStringExtra(EXTRA_VIDEO_PATH)
        videoFilename = intent.getStringExtra(EXTRA_VIDEO_FILENAME)

        // Initialize views
        playerView = findViewById(R.id.playerView)
        loadingProgress = findViewById(R.id.loadingProgress)
        errorText = findViewById(R.id.errorText)
        closeButton = findViewById(R.id.closeButton)
        titleText = findViewById(R.id.titleText)

        // Set title
        titleText.text = videoFilename ?: "動画再生"

        // Close button
        closeButton.setOnClickListener {
            finish()
        }

        // Load video
        loadVideo()
    }

    private fun loadVideo() {
        if (videoPath == null) {
            showError("動画パスが指定されていません")
            return
        }

        loadingProgress.visibility = View.VISIBLE
        errorText.visibility = View.GONE

        // Construct video URL
        val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')
        val videoUrl = "$baseUrl/storj/images/$videoPath?thumbnail=false"

        Log.d(TAG, "=== Video Load Details ===")
        Log.d(TAG, "videoPath: $videoPath")
        Log.d(TAG, "baseUrl (trimmed): $baseUrl")
        Log.d(TAG, "Full videoUrl: $videoUrl")
        Log.d(TAG, "=========================")

        try {
            initializePlayer(videoUrl)
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing player", e)
            showError("動画の初期化に失敗しました: ${e.message}")
        }
    }

    private fun initializePlayer(videoUrl: String) {
        // Create player
        player = ExoPlayer.Builder(this).build().also { exoPlayer ->
            playerView.player = exoPlayer

            // Create media item
            val mediaItem = MediaItem.fromUri(videoUrl)
            exoPlayer.setMediaItem(mediaItem)

            // Add listener
            exoPlayer.addListener(object : Player.Listener {
                override fun onPlaybackStateChanged(playbackState: Int) {
                    when (playbackState) {
                        Player.STATE_BUFFERING -> {
                            loadingProgress.visibility = View.VISIBLE
                            Log.d(TAG, "Player state: BUFFERING")
                        }
                        Player.STATE_READY -> {
                            loadingProgress.visibility = View.GONE
                            errorText.visibility = View.GONE
                            Log.d(TAG, "Player state: READY")
                        }
                        Player.STATE_ENDED -> {
                            Log.d(TAG, "Player state: ENDED")
                        }
                        Player.STATE_IDLE -> {
                            Log.d(TAG, "Player state: IDLE")
                        }
                    }
                }

                override fun onPlayerError(error: PlaybackException) {
                    Log.e(TAG, "Player error: ${error.message}", error)
                    showError("動画の再生に失敗しました: ${error.message}")
                }
            })

            // Prepare and play
            exoPlayer.prepare()
            exoPlayer.playWhenReady = playWhenReady
            exoPlayer.seekTo(currentPosition)
        }

        Log.d(TAG, "Player initialized with URL: $videoUrl")
    }

    private fun showError(message: String) {
        loadingProgress.visibility = View.GONE
        errorText.visibility = View.VISIBLE
        errorText.text = message
        Log.e(TAG, "Error: $message")
    }

    override fun onStart() {
        super.onStart()
        if (player == null && videoPath != null) {
            val baseUrl = RetrofitClient.BASE_URL.trimEnd('/')
            val videoUrl = "$baseUrl/storj/images/$videoPath?thumbnail=false"
            initializePlayer(videoUrl)
        }
    }

    override fun onResume() {
        super.onResume()
        player?.let {
            it.playWhenReady = playWhenReady
            it.seekTo(currentPosition)
        }
    }

    override fun onPause() {
        super.onPause()
        player?.let {
            playWhenReady = it.playWhenReady
            currentPosition = it.currentPosition
        }
    }

    override fun onStop() {
        super.onStop()
        releasePlayer()
    }

    override fun onDestroy() {
        super.onDestroy()
        releasePlayer()
    }

    private fun releasePlayer() {
        player?.let {
            playWhenReady = it.playWhenReady
            currentPosition = it.currentPosition
            it.release()
        }
        player = null
    }
}
