package com.example.storjapp.adapter

import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
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
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<PhotoItem>) {
        items.clear()
        items.addAll(newItems)
        Log.d(TAG, "Updated items: ${newItems.size} total (${newItems.count { it.isFromStorj }} from Storj, ${newItems.count { !it.isFromStorj }} local)")
        notifyDataSetChanged()
    }
}
