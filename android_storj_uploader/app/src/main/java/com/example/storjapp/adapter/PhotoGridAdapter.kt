package com.example.storjapp.adapter

import android.content.Intent
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.example.storjapp.ImageViewerActivity
import com.example.storjapp.VideoPlayerActivity
import com.example.storjapp.R
import com.example.storjapp.model.PhotoItem

class PhotoGridAdapter : RecyclerView.Adapter<PhotoGridAdapter.ViewHolder>() {

    companion object {
        private const val TAG = "PhotoGridAdapter"
    }

    private val items = mutableListOf<PhotoItem>()

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val photoImage: ImageView = view.findViewById(R.id.photoImage)
        val uploadBadge: TextView = view.findViewById(R.id.uploadBadge)
        val videoPlayIcon: ImageView = view.findViewById(R.id.videoPlayIcon)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_photo_grid, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        val adapterPosition = holder.bindingAdapterPosition

        // Load image thumbnail from URI (local) or URL (Storj)
        val imageSource = if (item.uri != null) {
            item.uri
        } else {
            item.storjUrl
        }

        Log.d(TAG, "Loading media at position $adapterPosition: uri=${item.uri}, storjUrl=${item.storjUrl}, isVideo=${item.isVideo}, isFromStorj=${item.isFromStorj}")

        Glide.with(holder.itemView.context)
            .load(imageSource)
            .centerCrop()
            .diskCacheStrategy(DiskCacheStrategy.ALL)
            .placeholder(android.R.drawable.ic_menu_gallery)
            .error(android.R.drawable.ic_menu_report_image)
            .listener(object : com.bumptech.glide.request.RequestListener<android.graphics.drawable.Drawable> {
                override fun onLoadFailed(
                    e: com.bumptech.glide.load.engine.GlideException?,
                    model: Any?,
                    target: com.bumptech.glide.request.target.Target<android.graphics.drawable.Drawable>,
                    isFirstResource: Boolean
                ): Boolean {
                    val currentPos = holder.bindingAdapterPosition
                    Log.e(TAG, "Failed to load image at position $currentPos from $imageSource", e)
                    return false
                }

                override fun onResourceReady(
                    resource: android.graphics.drawable.Drawable,
                    model: Any,
                    target: com.bumptech.glide.request.target.Target<android.graphics.drawable.Drawable>?,
                    dataSource: com.bumptech.glide.load.DataSource,
                    isFirstResource: Boolean
                ): Boolean {
                    val currentPos = holder.bindingAdapterPosition
                    Log.d(TAG, "Successfully loaded image at position $currentPos from $imageSource")
                    return false
                }
            })
            .into(holder.photoImage)

        // Show upload status badge
        if (item.isUploaded) {
            holder.uploadBadge.visibility = View.VISIBLE
            holder.uploadBadge.text = "✓"
            holder.uploadBadge.setBackgroundColor(
                holder.itemView.context.getColor(android.R.color.holo_green_dark)
            )
        } else {
            holder.uploadBadge.visibility = View.GONE
        }

        // Show video play icon if this is a video
        if (item.isVideo) {
            holder.videoPlayIcon.visibility = View.VISIBLE
        } else {
            holder.videoPlayIcon.visibility = View.GONE
        }

        // Set click listener to open ImageViewerActivity or VideoPlayerActivity
        holder.itemView.setOnClickListener {
            Log.d(TAG, "Item clicked - isFromStorj: ${item.isFromStorj}, isVideo: ${item.isVideo}, storjPath: ${item.storjPath}, uri: ${item.uri}, fileName: ${item.fileName}")

            if (item.isFromStorj && item.storjPath != null) {
                try {
                    val context = holder.itemView.context

                    if (item.isVideo) {
                        // Open VideoPlayerActivity for videos
                        Log.d(TAG, "Video clicked: ${item.fileName}")
                        val intent = Intent(context, VideoPlayerActivity::class.java).apply {
                            putExtra(VideoPlayerActivity.EXTRA_VIDEO_PATH, item.storjPath)
                            putExtra(VideoPlayerActivity.EXTRA_VIDEO_FILENAME, item.fileName)
                        }
                        context.startActivity(intent)
                        Log.d(TAG, "Successfully opened VideoPlayerActivity for: ${item.fileName}")
                    } else {
                        // Open ImageViewerActivity for images
                        val intent = Intent(context, ImageViewerActivity::class.java).apply {
                            putExtra(ImageViewerActivity.EXTRA_IMAGE_PATH, item.storjPath)
                            putExtra(ImageViewerActivity.EXTRA_IMAGE_FILENAME, item.fileName)
                            putExtra(ImageViewerActivity.EXTRA_IMAGE_SIZE, 0L) // Size not available in PhotoItem
                            putExtra(ImageViewerActivity.EXTRA_IMAGE_DATE, "") // Date not available in PhotoItem
                        }
                        context.startActivity(intent)
                        Log.d(TAG, "Successfully opened ImageViewerActivity for: ${item.fileName}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening viewer activity", e)
                    android.widget.Toast.makeText(
                        holder.itemView.context,
                        "ファイルを開けませんでした: ${e.message}",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
            } else if (item.isFromStorj && item.storjPath == null) {
                Log.w(TAG, "Storj image clicked but storjPath is null: ${item.fileName}")
                android.widget.Toast.makeText(
                    holder.itemView.context,
                    "画像パスが見つかりません",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            } else if (!item.isFromStorj && item.uri != null) {
                // Handle local media (photos/videos)
                try {
                    val context = holder.itemView.context

                    if (item.isVideo) {
                        // Open VideoPlayerActivity for local videos
                        Log.d(TAG, "Local video clicked: ${item.fileName}")
                        val intent = Intent(context, VideoPlayerActivity::class.java).apply {
                            putExtra(VideoPlayerActivity.EXTRA_VIDEO_PATH, item.uri.toString())
                            putExtra(VideoPlayerActivity.EXTRA_VIDEO_FILENAME, item.fileName)
                        }
                        context.startActivity(intent)
                        Log.d(TAG, "Successfully opened VideoPlayerActivity for local video: ${item.fileName}")
                    } else {
                        // Local photo clicked - no viewer yet
                        Log.d(TAG, "Local photo clicked (no viewer for local photos yet)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening local media viewer", e)
                    android.widget.Toast.makeText(
                        holder.itemView.context,
                        "ファイルを開けませんでした: ${e.message}",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                }
            } else {
                Log.d(TAG, "Item clicked but no valid path or URI")
            }
        }
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<PhotoItem>) {
        items.clear()
        items.addAll(newItems)
        Log.d(TAG, "Updated items: ${newItems.size} total (${newItems.count { it.isFromStorj }} from Storj, ${newItems.count { !it.isFromStorj }} local)")
        notifyDataSetChanged()
    }
}
