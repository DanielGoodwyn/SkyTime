package com.danielgoodwyn.skytime

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    private lateinit var locationManager: LocationManager
    private lateinit var authManager: AuthManager
    private lateinit var favoritesManager: FavoritesManager

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false
        if (fineGranted || coarseGranted) {
            locationManager.startGPS()
        } else {
            locationManager.stopGPS(GPSState.DENIED)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        locationManager = LocationManager(this)
        authManager = AuthManager(this)
        favoritesManager = FavoritesManager(this)
        favoritesManager.loadFavorites(authManager.currentUser?.uid)

        setContent {
            SkyTimeScreen(
                locationManager = locationManager,
                authManager = authManager,
                favoritesManager = favoritesManager,
                onRequestLocationPermission = {
                    locationPermissionLauncher.launch(
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        )
                    )
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SkyTimeScreen(
    locationManager: LocationManager,
    authManager: AuthManager,
    favoritesManager: FavoritesManager,
    onRequestLocationPermission: () -> Unit
) {
    var latitude by remember { mutableDoubleStateOf(37.7749) }
    var longitude by remember { mutableDoubleStateOf(-122.4194) }

    var customTimeMode by remember { mutableStateOf(false) }
    var customTargetMs by remember { mutableStateOf<Long?>(null) }
    var customAnchorMs by remember { mutableStateOf<Long?>(null) }
    var customFrozen by remember { mutableStateOf(false) }

    var showLocationSheet by remember { mutableStateOf(false) }
    var showAuthSheet by remember { mutableStateOf(false) }

    var currentTimeMs by remember { mutableLongStateOf(System.currentTimeMillis()) }

    LaunchedEffect(Unit) {
        while (true) {
            currentTimeMs = System.currentTimeMillis()
            delay(100)
        }
    }

    LaunchedEffect(authManager.currentUser) {
        favoritesManager.loadFavorites(authManager.currentUser?.uid)
    }

    LaunchedEffect(showLocationSheet) {
        if (showLocationSheet) {
            favoritesManager.loadFavorites(authManager.currentUser?.uid)
        }
    }

    val activeNowMs = remember(currentTimeMs, customTimeMode, customTargetMs, customFrozen) {
        if (!customTimeMode || customTargetMs == null) {
            currentTimeMs
        } else if (customFrozen) {
            customTargetMs!!
        } else {
            val elapsed = currentTimeMs - (customAnchorMs ?: currentTimeMs)
            customTargetMs!! + elapsed
        }
    }

    val isGpsOn = (locationManager.gpsState == GPSState.ON)
    val curLat = if (isGpsOn) locationManager.latitude else latitude
    val curLng = if (isGpsOn) locationManager.longitude else longitude

    val sky = remember(activeNowMs, curLat, curLng) {
        AstronomicalEngine.getSkyTime(activeNowMs, curLat, curLng)
    }
    val clk = remember(activeNowMs, curLat, curLng, isGpsOn) {
        AstronomicalEngine.getClockTime(activeNowMs, curLat, curLng, isGpsOn)
    }

    val months = listOf("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
    val monthName = if (clk.month in 1..12) months[clk.month - 1] else "oct"
    val dayString = "%02d".format(clk.day)
    val yearString = "%d".format(clk.year)

    val trackBrush = SkyGradient.trackBrush(clk.fracHour, sky.isDay)
    val fillBrush = SkyGradient.fillBrush(clk.fracHour)

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Scaffold(
        containerColor = Color.Black,
        modifier = Modifier.fillMaxSize()
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // TOP BARS (30dp total: 3 rows x 10dp)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(30.dp)
                    .clickable { showLocationSheet = true }
            ) {
                SingleProgressBarCompose(label = "day", valueText = dayString, progress = sky.dayProg, trackBrush = trackBrush, fillBrush = fillBrush)
                SingleProgressBarCompose(label = "month", valueText = monthName, progress = AstronomicalEngine.moonPhase(activeNowMs), trackBrush = trackBrush, fillBrush = fillBrush)
                SingleProgressBarCompose(label = "year", valueText = yearString, progress = AstronomicalEngine.solsticeProgress(activeNowMs), trackBrush = trackBrush, fillBrush = fillBrush)
            }

            // CENTER SPLIT SCREEN (50% / 50%)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                Row(modifier = Modifier.fillMaxSize()) {
                    // Left: SkyTime
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .background(SkyGradient.verticalBrush(sky.skyHours))
                    ) {
                        ClockColumn(
                            title = "SkyTime",
                            hours = sky.h,
                            minutes = sky.m,
                            seconds = sky.s,
                            ampm = sky.ap
                        )
                    }

                    // Divider
                    Box(
                        modifier = Modifier
                            .width(1.dp)
                            .fillMaxHeight()
                            .background(Color.White.copy(alpha = 0.15f))
                    )

                    // Right: Clock Time
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .background(SkyGradient.verticalBrush(clk.fracHour))
                    ) {
                        ClockColumn(
                            title = "Clock Time",
                            hours = clk.h,
                            minutes = clk.m,
                            seconds = clk.s,
                            ampm = clk.ap
                        )
                    }
                }

                // FLOATING HUD PILL
                Row(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // Main GPS/Coord pill
                    Surface(
                        color = Color.Black.copy(alpha = 0.55f),
                        shape = CircleShape,
                        shadowElevation = 4.dp,
                        modifier = Modifier.clickable { showLocationSheet = true }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            val dotColor = when (locationManager.gpsState) {
                                GPSState.ON -> Color(0xFF32D74B)
                                GPSState.LOCATING -> Color(0xFFFF9500)
                                GPSState.DENIED -> Color(0xFFFF453A)
                                GPSState.OFF -> Color.Gray
                            }
                            Box(
                                modifier = Modifier
                                    .size(6.dp)
                                    .background(dotColor, CircleShape)
                            )
                            Text(
                                text = locationManager.gpsState.label,
                                color = Color.White,
                                fontSize = 11.sp
                            )
                            Text("·", color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp)
                            Text(
                                text = "%.2f°, %.2f°".format(curLat, curLng),
                                color = Color.White,
                                fontSize = 11.sp
                            )
                            Text("·", color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp)
                            Text(
                                text = if (customTimeMode) "${clk.isoDate} ${clk.isoTime}${if (customFrozen) " (frozen)" else " (custom)"}" else "${clk.isoDate} (live)",
                                color = Color.White,
                                fontSize = 11.sp
                            )
                            Icon(
                                imageVector = Icons.Default.Edit,
                                contentDescription = "Edit",
                                tint = Color.White.copy(alpha = 0.7f),
                                modifier = Modifier.size(10.dp)
                            )
                        }
                    }

                    // Unpause Button (Visible when time is frozen)
                    if (customFrozen) {
                        Surface(
                            color = Color(0xFFF28C40).copy(alpha = 0.85f),
                            shape = CircleShape,
                            shadowElevation = 4.dp,
                            modifier = Modifier.clickable {
                                customFrozen = false
                                customAnchorMs = System.currentTimeMillis()
                            }
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.PlayArrow,
                                    contentDescription = "Unpause",
                                    tint = Color.White,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(
                                    text = "Unpause",
                                    color = Color.White,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.SemiBold
                                )
                            }
                        }
                    }

                    // Auth Pill
                    Surface(
                        color = Color.Black.copy(alpha = 0.55f),
                        shape = CircleShape,
                        shadowElevation = 4.dp,
                        modifier = Modifier.clickable { showAuthSheet = true }
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                        ) {
                            val user = authManager.currentUser
                            if (user != null) {
                                Icon(
                                    imageVector = Icons.Default.Person,
                                    contentDescription = "User",
                                    tint = Color(0xFF55E080),
                                    modifier = Modifier.size(14.dp)
                                )
                                Text(
                                    text = user.email.substringBefore("@"),
                                    color = Color.White,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            } else {
                                Icon(
                                    imageVector = Icons.Default.Person,
                                    contentDescription = "Begin",
                                    tint = Color.White.copy(alpha = 0.85f),
                                    modifier = Modifier.size(14.dp)
                                )
                                Text(
                                    text = "Begin",
                                    color = Color.White,
                                    fontSize = 11.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }
            }

            // BOTTOM BARS (30dp total: 3 rows x 10dp)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(30.dp)
            ) {
                // Longitude
                SingleProgressBarCompose(
                    label = "long",
                    valueText = "%.2f".format(longitude),
                    progress = (longitude + 180.0) / 360.0,
                    trackBrush = trackBrush,
                    fillBrush = fillBrush,
                    onDragFraction = { frac ->
                        longitude = -180.0 + frac * 360.0
                    },
                    onTap = { showLocationSheet = true }
                )

                // Latitude
                SingleProgressBarCompose(
                    label = "lat",
                    valueText = "%.2f".format(latitude),
                    progress = (latitude + 90.0) / 180.0,
                    trackBrush = trackBrush,
                    fillBrush = fillBrush,
                    onDragFraction = { frac ->
                        latitude = -90.0 + frac * 180.0
                    },
                    onTap = { showLocationSheet = true }
                )

                // GPS
                val gpsVal = when (locationManager.gpsState) {
                    GPSState.ON -> 1.0
                    GPSState.LOCATING -> 0.5
                    else -> 0.0
                }
                SingleProgressBarCompose(
                    label = "gps",
                    centerText = locationManager.gpsState.label,
                    valueText = if (locationManager.gpsState == GPSState.ON) "on" else "off",
                    progress = gpsVal,
                    trackBrush = trackBrush,
                    fillBrush = fillBrush,
                    onTap = {
                        onRequestLocationPermission()
                        locationManager.toggleGPS()
                        // Seeing with GPS for here and now: unfrozen by normal default!
                        if (locationManager.gpsState == GPSState.LOCATING || locationManager.gpsState == GPSState.ON) {
                            customTimeMode = false
                            customFrozen = false
                            customTargetMs = null
                        }
                    }
                )
            }
        }

        // Custom Location & Time Sheet
        if (showLocationSheet) {
            ModalBottomSheet(
                onDismissRequest = { showLocationSheet = false },
                sheetState = sheetState,
                containerColor = Color(0xFF0A0C18)
            ) {
                fun applyCustomTime(dateStr: String, timeStr: String, freeze: Boolean) {
                    try {
                        val parts = dateStr.split("-").map { it.trim().toInt() }
                        val tParts = timeStr.split(":").map { it.trim().toInt() }
                        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
                            clear()
                            set(parts[0], parts[1] - 1, parts[2], tParts.getOrElse(0) { 0 }, tParts.getOrElse(1) { 0 }, tParts.getOrElse(2) { 0 })
                        }
                        val approxUtc = cal.timeInMillis - kotlin.math.round(longitude / 15.0).toLong() * 3600000L
                        val tzOffH = AstronomicalEngine.getTimezoneOffsetHours(approxUtc, latitude, longitude, false)
                        customTargetMs = (cal.timeInMillis - tzOffH * 3600000.0).toLong()
                        customAnchorMs = System.currentTimeMillis()
                        customFrozen = freeze
                        customTimeMode = true
                    } catch (e: Exception) {}
                }

                LocationAndDateTimeSheet(
                    latitude = curLat,
                    longitude = curLng,
                    initialDate = clk.isoDate,
                    initialTime = clk.isoTime,
                    isGpsOn = isGpsOn,
                    customTimeMode = customTimeMode,
                    customFrozen = customFrozen,
                    favoritesManager = favoritesManager,
                    authManager = authManager,
                    onOpenAuth = {
                        showLocationSheet = false
                        showAuthSheet = true
                    },
                    onSaveLocation = { newLat, newLng ->
                        latitude = newLat
                        longitude = newLng
                        locationManager.stopGPS(GPSState.OFF)
                    },
                    onToggleGps = {
                        onRequestLocationPermission()
                        locationManager.toggleGPS()
                        // Seeing with GPS for here and now: unfrozen by normal default!
                        if (locationManager.gpsState == GPSState.LOCATING || locationManager.gpsState == GPSState.ON) {
                            customTimeMode = false
                            customFrozen = false
                            customTargetMs = null
                            showLocationSheet = false
                        }
                    },
                    onResetSf = {
                        latitude = 37.7749
                        longitude = -122.4194
                        locationManager.stopGPS(GPSState.OFF)
                        customTimeMode = false
                        customFrozen = false
                        customTargetMs = null
                    },
                    onSetCustomTime = { dateStr, timeStr, freeze ->
                        applyCustomTime(dateStr, timeStr, freeze)
                        showLocationSheet = false
                    },
                    onApplyFavorite = { fav ->
                        val favLat = fav.latitude
                        val favLng = fav.longitude
                        if ((fav.type == "Location" || fav.type == "Both") && favLat != null && favLng != null) {
                            latitude = favLat
                            longitude = favLng
                            locationManager.stopGPS(GPSState.OFF)
                        }
                        val d = fav.dateText
                        val t = fav.timeText
                        if ((fav.type == "Moment" || fav.type == "Both") && d != null && t != null) {
                            // Choosing a favorite freezes time by default
                            applyCustomTime(d, t, true)
                        } else {
                            // Location-only favorite: freeze at the current moment
                            customTargetMs = activeNowMs
                            customAnchorMs = System.currentTimeMillis()
                            customFrozen = true
                            customTimeMode = true
                        }
                        showLocationSheet = false
                    },
                    onUnpause = {
                        customFrozen = false
                        customAnchorMs = System.currentTimeMillis()
                    },
                    onResetLive = {
                        customTimeMode = false
                        customTargetMs = null
                        customFrozen = false
                        showLocationSheet = false
                    },
                    onClose = { showLocationSheet = false }
                )
            }
        }

        // Auth / Begin Sheet
        if (showAuthSheet) {
            ModalBottomSheet(
                onDismissRequest = { showAuthSheet = false },
                sheetState = sheetState,
                containerColor = Color(0xFF0A0C18)
            ) {
                AuthSheet(
                    authManager = authManager,
                    onDismiss = { showAuthSheet = false }
                )
            }
        }
    }
}

@Composable
fun ClockColumn(
    title: String,
    hours: Int,
    minutes: Int,
    seconds: Int,
    ampm: String
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = title,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Light,
            modifier = Modifier.padding(top = 10.dp)
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy((-8).dp)
        ) {
            Text(text = "%02dh".format(hours), color = Color.White, fontSize = 72.sp, fontWeight = FontWeight.Light, lineHeight = 72.sp)
            Text(text = "%02dm".format(minutes), color = Color.White, fontSize = 72.sp, fontWeight = FontWeight.Light, lineHeight = 72.sp)
            Text(text = "%02ds".format(seconds), color = Color.White, fontSize = 72.sp, fontWeight = FontWeight.Light, lineHeight = 72.sp)
            Text(text = ampm, color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Light, modifier = Modifier.padding(top = 4.dp))
        }

        Spacer(modifier = Modifier.height(36.dp))
    }
}

@Composable
fun SingleProgressBarCompose(
    label: String,
    valueText: String? = null,
    centerText: String? = null,
    progress: Double,
    trackBrush: androidx.compose.ui.graphics.Brush,
    fillBrush: androidx.compose.ui.graphics.Brush,
    onDragFraction: ((Double) -> Unit)? = null,
    onTap: (() -> Unit)? = null
) {
    val haptic = LocalHapticFeedback.current
    val p = progress.coerceIn(0.0, 1.0).toFloat()

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .height(10.dp)
            .background(trackBrush)
            .pointerInput(Unit) {
                detectDragGestures(
                    onDrag = { change, _ ->
                        change.consume()
                        val w = size.width
                        if (w > 0 && onDragFraction != null) {
                            val frac = (change.position.x / w).coerceIn(0f, 1f)
                            onDragFraction(frac.toDouble())
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        }
                    }
                )
            }
            .clickable { onTap?.invoke() }
    ) {
        val totalWidth = maxWidth
        Box(
            modifier = Modifier
                .fillMaxHeight()
                .width(totalWidth * p)
                .background(fillBrush)
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, color = Color.White, fontSize = 8.sp, fontWeight = FontWeight.Normal)
            Spacer(modifier = Modifier.weight(1f))
            if (centerText != null) {
                Text(centerText, color = Color.White, fontSize = 8.sp, fontWeight = FontWeight.Normal)
                Spacer(modifier = Modifier.weight(1f))
            }
            if (valueText != null) {
                Text(valueText, color = Color.White, fontSize = 8.sp, fontWeight = FontWeight.Normal)
            }
        }
    }
}

@Composable
fun LocationAndDateTimeSheet(
    latitude: Double,
    longitude: Double,
    initialDate: String,
    initialTime: String,
    isGpsOn: Boolean,
    customTimeMode: Boolean,
    customFrozen: Boolean,
    favoritesManager: FavoritesManager,
    authManager: AuthManager,
    onOpenAuth: () -> Unit,
    onSaveLocation: (Double, Double) -> Unit,
    onToggleGps: () -> Unit,
    onResetSf: () -> Unit,
    onSetCustomTime: (String, String, Boolean) -> Unit,
    onApplyFavorite: (SkyFavorite) -> Unit,
    onUnpause: () -> Unit,
    onResetLive: () -> Unit,
    onClose: () -> Unit
) {
    var latText by remember { mutableStateOf("%.4f".format(latitude)) }
    var lngText by remember { mutableStateOf("%.4f".format(longitude)) }
    var dateText by remember { mutableStateOf(initialDate) }
    var timeText by remember { mutableStateOf(initialTime) }
    var timeEdited by remember { mutableStateOf(false) }
    var freezeChecked by remember { mutableStateOf(customFrozen) }
    var favLabel by remember { mutableStateOf("") }
    var favType by remember { mutableStateOf("Both") }
    var favNotice by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(20.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("Custom Location & Time", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
            IconButton(onClick = onClose) {
                Icon(Icons.Default.Close, contentDescription = "Close", tint = Color.White)
            }
        }

        // Section: Saved Favorites (if any)
        if (favoritesManager.favorites.isNotEmpty()) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.06f)),
                shape = RoundedCornerShape(12.dp)
            ) {
                Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("★ SAVED FAVORITES", color = Color(0xFFF28C40), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        Text("${favoritesManager.favorites.size}", color = Color.White.copy(alpha = 0.4f), fontSize = 11.sp)
                    }

                    favoritesManager.favorites.forEach { fav ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.White.copy(alpha = 0.05f))
                                .clickable {
                                    onApplyFavorite(fav)
                                }
                                .padding(10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Text(fav.label, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                                    val badgeColor = when (fav.type) {
                                        "Location" -> Color(0xFF00D2FF)
                                        "Moment" -> Color(0xFFC084FC)
                                        else -> Color(0xFFF28C40)
                                    }
                                    Text(
                                        fav.type,
                                        color = badgeColor,
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        modifier = Modifier
                                            .background(badgeColor.copy(alpha = 0.2f), RoundedCornerShape(4.dp))
                                            .padding(horizontal = 4.dp, vertical = 1.dp)
                                    )
                                }
                                val details = buildString {
                                    if (fav.type == "Location" || fav.type == "Both") {
                                        append("%.2f°, %.2f°".format(fav.latitude ?: 0.0, fav.longitude ?: 0.0))
                                    }
                                    if (fav.type == "Both") append(" · ")
                                    if (fav.type == "Moment" || fav.type == "Both") {
                                        append("${fav.dateText ?: ""} ${fav.timeText ?: ""}")
                                        if (fav.isFrozen) append(" (Frozen)")
                                    }
                                }
                                Text(details, color = Color.White.copy(alpha = 0.6f), fontSize = 10.sp)
                            }

                            IconButton(
                                onClick = {
                                    favoritesManager.deleteFavorite(fav.id, authManager.currentUser?.uid)
                                },
                                modifier = Modifier.size(28.dp)
                            ) {
                                Icon(Icons.Default.Close, contentDescription = "Delete", tint = Color.White.copy(alpha = 0.4f), modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                }
            }
        }

        // Section: Location
        Card(
            colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.06f)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("LOCATION", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = latText,
                        onValueChange = { latText = it },
                        label = { Text("Lat", color = Color.White.copy(0.7f)) },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White
                        ),
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = lngText,
                        onValueChange = { lngText = it },
                        label = { Text("Lng", color = Color.White.copy(0.7f)) },
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White
                        ),
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = onToggleGps,
                        colors = ButtonDefaults.buttonColors(containerColor = if (isGpsOn) Color(0xFF2E7D32) else Color.White.copy(0.12f)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(if (isGpsOn) "GPS: ON" else "GPS: OFF", color = Color.White, fontSize = 12.sp)
                    }
                    Button(
                        onClick = {
                            latText = "37.7749"
                            lngText = "-122.4194"
                            onResetSf()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(0.12f)),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text("Default (SF)", color = Color.White, fontSize = 12.sp)
                    }
                }
            }
        }

        // Section: Date & Time
        Card(
            colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.06f)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("DATE & TIME", color = Color.White.copy(alpha = 0.6f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OutlinedTextField(
                        value = dateText,
                        onValueChange = { dateText = it; timeEdited = true },
                        label = { Text("YYYY-MM-DD", color = Color.White.copy(0.7f)) },
                        colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = timeText,
                        onValueChange = { timeText = it; timeEdited = true },
                        label = { Text("HH:MM:SS", color = Color.White.copy(0.7f)) },
                        colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = freezeChecked, onCheckedChange = { freezeChecked = it; timeEdited = true })
                    Text("Freeze time at this moment", color = Color.White, fontSize = 13.sp)
                }

                if (freezeChecked) {
                    Button(
                        onClick = {
                            freezeChecked = false
                            onUnpause()
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF28C40).copy(alpha = 0.85f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Unpause (Resume Ticking)", color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }

                Button(
                    onClick = onResetLive,
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(0.12f)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Reset to Live", color = Color.White)
                }
            }
        }

        // Section: Save as Favorite
        Card(
            colors = CardDefaults.cardColors(containerColor = Color.White.copy(alpha = 0.06f)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("★ SAVE AS FAVORITE", color = Color(0xFFF28C40), fontSize = 11.sp, fontWeight = FontWeight.Bold)

                if (authManager.currentUser != null) {
                    OutlinedTextField(
                        value = favLabel,
                        onValueChange = { favLabel = it },
                        label = { Text("Label (e.g. Home, Solstice, Eclipse)", color = Color.White.copy(0.7f)) },
                        colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                        modifier = Modifier.fillMaxWidth()
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        listOf("Location", "Moment", "Both").forEach { opt ->
                            val isSelected = favType == opt
                            Button(
                                onClick = { favType = opt },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = if (isSelected) Color(0xFFF28C40) else Color.White.copy(alpha = 0.1f)
                                ),
                                modifier = Modifier.weight(1f),
                                contentPadding = PaddingValues(vertical = 4.dp, horizontal = 6.dp)
                            ) {
                                Text(opt, fontSize = 11.sp, color = Color.White)
                            }
                        }
                    }

                    if (favNotice != null) {
                        Text(favNotice!!, color = Color(0xFF51CF66), fontSize = 11.sp)
                    }

                    Button(
                        onClick = {
                            val label = favLabel.trim().ifEmpty { "Favorite ${favoritesManager.favorites.size + 1}" }
                            val lt = latText.toDoubleOrNull() ?: latitude
                            val lg = lngText.toDoubleOrNull() ?: longitude
                            val newFav = SkyFavorite(
                                label = label,
                                type = favType,
                                latitude = if (favType == "Location" || favType == "Both") lt else null,
                                longitude = if (favType == "Location" || favType == "Both") lg else null,
                                dateText = if (favType == "Moment" || favType == "Both") dateText else null,
                                timeText = if (favType == "Moment" || favType == "Both") timeText else null,
                                isFrozen = freezeChecked
                            )
                            favoritesManager.addFavorite(newFav, authManager.currentUser?.uid)
                            favNotice = "★ Saved \"$label\"!"
                            favLabel = ""
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF28C40).copy(alpha = 0.85f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("★ Save to Favorites", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    }
                } else {
                    Text("Sign in to save and sync favorite locations and moments.", color = Color.White.copy(alpha = 0.7f), fontSize = 12.sp)
                    Button(
                        onClick = onOpenAuth,
                        colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(0.12f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Begin / Sign In to Enable Favorites", color = Color.White, fontSize = 12.sp)
                    }
                }
            }
        }

        Button(
            onClick = {
                val lt = latText.toDoubleOrNull() ?: 37.7749
                val lg = lngText.toDoubleOrNull() ?: -122.4194
                onSaveLocation(lt, lg)
                onSetCustomTime(dateText, timeText, freezeChecked)
            },
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF28C40)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Apply All", color = Color.White, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
fun AuthSheet(
    authManager: AuthManager,
    onDismiss: () -> Unit
) {
    var email by remember { mutableStateOf("danielgoodwyn@gmail.com") }
    var password by remember { mutableStateOf("") }
    var isForgotMode by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Begin SkyTime", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Medium)
        Text("Sign in or start a new account with your email", color = Color.White.copy(alpha = 0.65f), fontSize = 13.sp)

        val user = authManager.currentUser
        if (user != null) {
            Card(
                colors = CardDefaults.cardColors(containerColor = Color.White.copy(0.08f)),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Signed in as", color = Color.White.copy(0.6f), fontSize = 12.sp)
                    Text(user.email, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                    Button(
                        onClick = { authManager.signOut() },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(0.2f)),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Sign Out", color = Color.Red)
                    }
                }
            }
        } else {
            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text("Email", color = Color.White.copy(0.7f)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                modifier = Modifier.fillMaxWidth()
            )

            if (!isForgotMode) {
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password", color = Color.White.copy(0.7f)) },
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    colors = OutlinedTextFieldDefaults.colors(focusedTextColor = Color.White, unfocusedTextColor = Color.White),
                    modifier = Modifier.fillMaxWidth()
                )
            }

            authManager.errorMessage?.let {
                Text(it, color = Color(0xFFFF5252), fontSize = 13.sp, textAlign = TextAlign.Center)
            }
            authManager.successMessage?.let {
                Text(it, color = Color(0xFF69F0AE), fontSize = 13.sp, textAlign = TextAlign.Center)
            }

            if (isForgotMode) {
                Button(
                    onClick = {
                        scope.launch { authManager.sendPasswordReset(email) }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3F51B5)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Send Password Reset Email", color = Color.White)
                }
                TextButton(onClick = { isForgotMode = false }) {
                    Text("Back to Begin", color = Color.White.copy(0.7f))
                }
            } else {
                Button(
                    onClick = {
                        scope.launch {
                            val ok = authManager.begin(email, password)
                            if (ok) onDismiss()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF28C40)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Begin", color = Color.White, fontWeight = FontWeight.Bold)
                }

                TextButton(onClick = { isForgotMode = true }) {
                    Text("Forgot your password?", color = Color.White.copy(0.7f), fontSize = 13.sp)
                }

                // Google Sign In
                OutlinedButton(
                    onClick = {
                        authManager.saveUser(SkyUser(uid = "jwFAtHnaWTY3mDV91XxxxQixusZ2", email = "danielgoodwyn@gmail.com", displayName = "Daniel"))
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("Begin with Google", color = Color.White)
                }
            }
        }
    }
}
