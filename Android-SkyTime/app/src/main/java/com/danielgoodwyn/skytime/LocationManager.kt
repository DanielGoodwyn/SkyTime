package com.danielgoodwyn.skytime

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager as AndroidLocationManager
import android.os.Bundle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

enum class GPSState(val label: String) {
    OFF("off"),
    LOCATING("locating..."),
    ON("on"),
    DENIED("off (denied)")
}

class LocationManager(private val context: Context) : LocationListener {

    var gpsState by mutableStateOf(GPSState.OFF)
    var latitude by mutableDoubleStateOf(37.7749)
    var longitude by mutableDoubleStateOf(-122.4194)

    private val androidLocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as AndroidLocationManager

    @SuppressLint("MissingPermission")
    fun startGPS() {
        gpsState = GPSState.LOCATING
        try {
            val isGpsEnabled = androidLocationManager.isProviderEnabled(AndroidLocationManager.GPS_PROVIDER)
            val isNetworkEnabled = androidLocationManager.isProviderEnabled(AndroidLocationManager.NETWORK_PROVIDER)

            if (!isGpsEnabled && !isNetworkEnabled) {
                gpsState = GPSState.DENIED
                return
            }

            if (isNetworkEnabled) {
                androidLocationManager.requestLocationUpdates(
                    AndroidLocationManager.NETWORK_PROVIDER,
                    2000L,
                    10f,
                    this
                )
                androidLocationManager.getLastKnownLocation(AndroidLocationManager.NETWORK_PROVIDER)?.let {
                    updateLocation(it)
                }
            }

            if (isGpsEnabled) {
                androidLocationManager.requestLocationUpdates(
                    AndroidLocationManager.GPS_PROVIDER,
                    2000L,
                    10f,
                    this
                )
                androidLocationManager.getLastKnownLocation(AndroidLocationManager.GPS_PROVIDER)?.let {
                    updateLocation(it)
                }
            }
        } catch (e: SecurityException) {
            gpsState = GPSState.DENIED
        }
    }

    fun stopGPS(newState: GPSState = GPSState.OFF) {
        try {
            androidLocationManager.removeUpdates(this)
        } catch (e: Exception) {
            // ignore
        }
        gpsState = newState
    }

    fun toggleGPS() {
        if (gpsState == GPSState.ON || gpsState == GPSState.LOCATING) {
            stopGPS(GPSState.OFF)
        } else {
            startGPS()
        }
    }

    private fun updateLocation(loc: Location) {
        latitude = loc.latitude.coerceIn(-90.0, 90.0)
        longitude = loc.longitude.coerceIn(-180.0, 180.0)
        gpsState = GPSState.ON
    }

    override fun onLocationChanged(location: Location) {
        updateLocation(location)
    }

    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
}
