package com.example.storjapp.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.example.storjapp.R
import com.example.storjapp.model.PhotoItem

class PhotoGridAdapter : RecyclerView.Adapter<PhotoGridAdapter.ViewHolder>() {

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

        // Load image thumbnail from URI (local) or URL (Storj)
        val imageSource = if (item.uri != null) {
            item.uri
        } else {
            item.storjUrl
        }

        Glide.with(holder.itemView.context)
            .load(imageSource)
            .centerCrop()
            .placeholder(android.R.drawable.ic_menu_gallery)
            .error(android.R.drawable.ic_menu_report_image)
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
        notifyDataSetChanged()
    }
}
