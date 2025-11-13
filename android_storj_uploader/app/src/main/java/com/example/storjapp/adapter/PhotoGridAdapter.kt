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

        Log.d(TAG, "Loading image at position $adapterPosition: uri=${item.uri}, storjUrl=${item.storjUrl}, source=$imageSource")

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

        // Set click listener to open ImageViewerActivity for Storj images
        holder.itemView.setOnClickListener {
            Log.d(TAG, "Item clicked - isFromStorj: ${item.isFromStorj}, storjPath: ${item.storjPath}, fileName: ${item.fileName}")

            if (item.isFromStorj && item.storjPath != null) {
                try {
                    val context = holder.itemView.context
                    val intent = Intent(context, ImageViewerActivity::class.java).apply {
                        putExtra(ImageViewerActivity.EXTRA_IMAGE_PATH, item.storjPath)
                        putExtra(ImageViewerActivity.EXTRA_IMAGE_FILENAME, item.fileName)
                        putExtra(ImageViewerActivity.EXTRA_IMAGE_SIZE, 0L) // Size not available in PhotoItem
                        putExtra(ImageViewerActivity.EXTRA_IMAGE_DATE, "") // Date not available in PhotoItem
                    }
                    context.startActivity(intent)
                    Log.d(TAG, "Successfully opened ImageViewerActivity for: ${item.fileName}")
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening ImageViewerActivity", e)
                    android.widget.Toast.makeText(
                        holder.itemView.context,
                        "画像を開けませんでした: ${e.message}",
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
            } else {
                Log.d(TAG, "Local image clicked (no viewer for local images yet)")
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
