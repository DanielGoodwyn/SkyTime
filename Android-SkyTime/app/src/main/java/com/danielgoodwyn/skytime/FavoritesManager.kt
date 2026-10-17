package com.danielgoodwyn.skytime

import android.content.Context
import androidx.compose.runtime.mutableStateListOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class SkyFavorite(
    val id: String = java.util.UUID.randomUUID().toString(),
    val label: String,
    val type: String, // "Location", "Moment", "Both"
    val latitude: Double? = null,
    val longitude: Double? = null,
    val dateText: String? = null,
    val timeText: String? = null,
    val isFrozen: Boolean = false,
    val createdAt: Long = System.currentTimeMillis()
) {
    fun toJsonObject(): JSONObject {
        val normType = when (type.lowercase()) {
            "location" -> "Location"
            "moment" -> "Moment"
            else -> "Both"
        }
        return JSONObject().apply {
            put("id", id)
            put("label", label)
            put("type", normType)
            latitude?.let {
                put("lat", it)
                put("latitude", it)
            }
            longitude?.let {
                put("lng", it)
                put("longitude", it)
            }
            dateText?.let {
                put("date", it)
                put("dateText", it)
            }
            timeText?.let {
                put("time", it)
                put("timeText", it)
            }
            put("frozen", isFrozen)
            put("isFrozen", isFrozen)
            put("createdAt", createdAt)
        }
    }

    companion object {
        fun fromJsonObject(obj: JSONObject): SkyFavorite {
            val id = obj.optString("id", java.util.UUID.randomUUID().toString())
            val label = obj.optString("label", "Favorite")
            val rawType = obj.optString("type", "Both")
            val normType = when (rawType.lowercase()) {
                "location" -> "Location"
                "moment" -> "Moment"
                else -> "Both"
            }
            val lat = if (obj.has("lat") && !obj.isNull("lat")) {
                obj.getDouble("lat")
            } else if (obj.has("latitude") && !obj.isNull("latitude")) {
                obj.getDouble("latitude")
            } else null

            val lng = if (obj.has("lng") && !obj.isNull("lng")) {
                obj.getDouble("lng")
            } else if (obj.has("longitude") && !obj.isNull("longitude")) {
                obj.getDouble("longitude")
            } else null

            val date = if (obj.has("date") && !obj.isNull("date")) {
                obj.getString("date")
            } else if (obj.has("dateText") && !obj.isNull("dateText")) {
                obj.getString("dateText")
            } else null

            val time = if (obj.has("time") && !obj.isNull("time")) {
                obj.getString("time")
            } else if (obj.has("timeText") && !obj.isNull("timeText")) {
                obj.getString("timeText")
            } else null

            val frozen = if (obj.has("frozen")) {
                obj.optBoolean("frozen", false)
            } else if (obj.has("isFrozen")) {
                obj.optBoolean("isFrozen", false)
            } else false

            val created = obj.optLong("createdAt", System.currentTimeMillis())

            return SkyFavorite(
                id = id,
                label = label,
                type = normType,
                latitude = lat,
                longitude = lng,
                dateText = date,
                timeText = time,
                isFrozen = frozen,
                createdAt = created
            )
        }
    }
}

class FavoritesManager(private val context: Context) {
    val favorites = mutableStateListOf<SkyFavorite>()

    private val prefs = context.getSharedPreferences("skytime_favs", Context.MODE_PRIVATE)
    private val scope = CoroutineScope(Dispatchers.Main)
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    private val apiKey = "AIzaSyCzUEuK46_qHYzxSS07GAprhtupTYsBNbs"
    private val projectId = "goodwyn-babynames"

    fun loadFavorites(uid: String?) {
        favorites.clear()
        val key = if (uid != null) "favs_$uid" else "favs_guest"
        val raw = prefs.getString(key, null)
        if (raw != null) {
            try {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    favorites.add(SkyFavorite.fromJsonObject(arr.getJSONObject(i)))
                }
            } catch (e: Exception) {}
        }

        if (uid != null) {
            fetchCloudFavorites(uid)
        }
    }

    fun saveFavorites(uid: String?) {
        val key = if (uid != null) "favs_$uid" else "favs_guest"
        val arr = JSONArray()
        for (fav in favorites) {
            arr.put(fav.toJsonObject())
        }
        prefs.edit().putString(key, arr.toString()).apply()
    }

    fun addFavorite(fav: SkyFavorite, uid: String?) {
        favorites.add(0, fav)
        saveFavorites(uid)
        if (uid != null) {
            syncFavoritesToCloud(uid)
        }
    }

    fun deleteFavorite(id: String, uid: String?) {
        favorites.removeAll { it.id == id }
        saveFavorites(uid)
        if (uid != null) {
            syncFavoritesToCloud(uid)
        }
    }

    fun fetchCloudFavorites(uid: String) {
        scope.launch {
            withContext(Dispatchers.IO) {
                try {
                    val url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/skytime_favorites/$uid?key=$apiKey"
                    val req = Request.Builder().url(url).get().build()
                    client.newCall(req).execute().use { res ->
                        if (res.code == 200) {
                            val bodyStr = res.body?.string() ?: ""
                            val root = JSONObject(bodyStr)
                            val fields = root.optJSONObject("fields")
                            val jsonField = fields?.optJSONObject("json")
                            val jsonString = jsonField?.optString("stringValue")
                            if (!jsonString.isNullOrEmpty()) {
                                val arr = JSONArray(jsonString)
                                val cloudList = mutableListOf<SkyFavorite>()
                                for (i in 0 until arr.length()) {
                                    cloudList.add(SkyFavorite.fromJsonObject(arr.getJSONObject(i)))
                                }
                                withContext(Dispatchers.Main) {
                                    favorites.clear()
                                    favorites.addAll(cloudList)
                                    saveFavorites(uid)
                                }
                            }
                        } else if (res.code == 404) {
                            // User document does not exist yet. If we have local favorites, push to cloud!
                            if (favorites.isNotEmpty()) {
                                syncFavoritesToCloud(uid)
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Retain local favorites offline
                }
            }
        }
    }

    fun syncFavoritesToCloud(uid: String) {
        scope.launch {
            withContext(Dispatchers.IO) {
                try {
                    val url = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/skytime_favorites/$uid?key=$apiKey"
                    val arr = JSONArray()
                    for (fav in favorites) {
                        arr.put(fav.toJsonObject())
                    }
                    val jsonString = arr.toString()

                    val payload = JSONObject().apply {
                        val fieldsObj = JSONObject().apply {
                            val jsonObj = JSONObject().apply {
                                put("stringValue", jsonString)
                            }
                            put("json", jsonObj)
                        }
                        put("fields", fieldsObj)
                    }

                    val body = payload.toString().toRequestBody("application/json".toMediaType())
                    val req = Request.Builder().url(url).patch(body).build()
                    client.newCall(req).execute().use { res ->
                        // Cloud sync complete
                    }
                } catch (e: Exception) {}
            }
        }
    }
}
