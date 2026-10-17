package com.danielgoodwyn.skytime

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import org.json.JSONArray
import org.json.JSONObject

data class SkyFavorite(
    val id: String = java.util.UUID.randomUUID().toString(),
    val label: String,
    val type: String, // "Location", "Moment", "Both"
    val latitude: Double? = null,
    val longitude: Double? = null,
    val dateText: String? = null,
    val timeText: String? = null,
    val isFrozen: Boolean = false
)

class FavoritesManager(private val context: Context) {
    val favorites = mutableStateListOf<SkyFavorite>()

    private val prefs = context.getSharedPreferences("skytime_favs", Context.MODE_PRIVATE)

    fun loadFavorites(uid: String?) {
        favorites.clear()
        val key = if (uid != null) "favs_$uid" else "favs_guest"
        val raw = prefs.getString(key, null) ?: return
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                favorites.add(
                    SkyFavorite(
                        id = obj.getString("id"),
                        label = obj.getString("label"),
                        type = obj.getString("type"),
                        latitude = if (obj.has("lat") && !obj.isNull("lat")) obj.getDouble("lat") else null,
                        longitude = if (obj.has("lng") && !obj.isNull("lng")) obj.getDouble("lng") else null,
                        dateText = if (obj.has("date") && !obj.isNull("date")) obj.getString("date") else null,
                        timeText = if (obj.has("time") && !obj.isNull("time")) obj.getString("time") else null,
                        isFrozen = obj.optBoolean("frozen", false)
                    )
                )
            }
        } catch (e: Exception) {}
    }

    fun saveFavorites(uid: String?) {
        val key = if (uid != null) "favs_$uid" else "favs_guest"
        val arr = JSONArray()
        for (fav in favorites) {
            val obj = JSONObject().apply {
                put("id", fav.id)
                put("label", fav.label)
                put("type", fav.type)
                fav.latitude?.let { put("lat", it) }
                fav.longitude?.let { put("lng", it) }
                fav.dateText?.let { put("date", it) }
                fav.timeText?.let { put("time", it) }
                put("frozen", fav.isFrozen)
            }
            arr.put(obj)
        }
        prefs.edit().putString(key, arr.toString()).apply()
    }

    fun addFavorite(fav: SkyFavorite, uid: String?) {
        favorites.add(0, fav)
        saveFavorites(uid)
    }

    fun deleteFavorite(id: String, uid: String?) {
        favorites.removeAll { it.id == id }
        saveFavorites(uid)
    }
}
