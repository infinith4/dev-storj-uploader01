package com.example.storjapp.adapter

import android.net.Uri
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.example.storjapp.R
import com.example.storjapp.model.UploadHistoryItem
import com.example.storjapp.model.UploadStatus
import java.text.SimpleDateFormat
import java.util.*

class UploadHistoryAdapter : RecyclerView.Adapter<UploadHistoryAdapter.ViewHolder>() {

    private val items = mutableListOf<UploadHistoryItem>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val thumbnailImage: ImageView = view.findViewById(R.id.thumbnailImage)
        val fileNameText: TextView = view.findViewById(R.id.fileNameText)
        val uploadTimeText: TextView = view.findViewById(R.id.uploadTimeText)
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
            .load(Uri.parse(item.photoUri))
            .centerCrop()
            .placeholder(android.R.drawable.ic_menu_gallery)
            .into(holder.thumbnailImage)

        // Set file name
        holder.fileNameText.text = item.fileName

        // Set upload time
        holder.uploadTimeText.text = dateFormat.format(Date(item.uploadTime))

        // Set status
        when (item.status) {
            UploadStatus.SUCCESS -> {
                holder.statusText.text = "Success"
                holder.statusText.setTextColor(
                    holder.itemView.context.getColor(android.R.color.holo_green_dark)
                )
            }
            UploadStatus.FAILED -> {
                holder.statusText.text = "Failed"
                holder.statusText.setTextColor(
                    holder.itemView.context.getColor(android.R.color.holo_red_dark)
                )
            }
            UploadStatus.PENDING -> {
                holder.statusText.text = "Pending"
                holder.statusText.setTextColor(
                    holder.itemView.context.getColor(android.R.color.holo_orange_dark)
                )
            }
        }
    }

    override fun getItemCount(): Int = items.size

    fun updateItems(newItems: List<UploadHistoryItem>) {
        items.clear()
        items.addAll(newItems)
        notifyDataSetChanged()
    }

    fun addItem(item: UploadHistoryItem) {
        items.add(0, item) // Add to beginning
        notifyItemInserted(0)
    }
}
