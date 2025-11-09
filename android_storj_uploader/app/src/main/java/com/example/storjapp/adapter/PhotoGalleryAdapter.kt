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
import java.text.SimpleDateFormat
import java.util.*

class PhotoGalleryAdapter : RecyclerView.Adapter<PhotoGalleryAdapter.ViewHolder>() {

    private val items = mutableListOf<PhotoItem>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val thumbnailImage: ImageView = view.findViewById(R.id.thumbnailImage)
        val fileNameText: TextView = view.findViewById(R.id.fileNameText)
        val dateAddedText: TextView = view.findViewById(R.id.uploadTimeText)
        val statusText: TextView = view.findViewById(R.id.statusText)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_upload_history, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]

        // Set thumbnail
        Glide.with(holder.itemView.context)
            .load(item.uri)
            .centerCrop()
            .placeholder(android.R.drawable.ic_menu_gallery)
            .into(holder.thumbnailImage)

        // Set file name
        holder.fileNameText.text = item.fileName

        // Set date added
        holder.dateAddedText.text = dateFormat.format(Date(item.dateAdded * 1000))

        // Set upload status
        if (item.isUploaded) {
            holder.statusText.text = "Uploaded"
            holder.statusText.setTextColor(
                holder.itemView.context.getColor(android.R.color.holo_green_dark)
            )
        } else {
            holder.statusText.text = "Not uploaded"
            holder.statusText.setTextColor(
                holder.itemView.context.getColor(android.R.color.holo_orange_dark)
            )
        }
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<PhotoItem>) {
        items.clear()
        items.addAll(newItems)
        notifyDataSetChanged()
    }
}
