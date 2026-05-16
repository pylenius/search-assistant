package fi.eport.searchassistant.location

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import fi.eport.searchassistant.AppConfig
import fi.eport.searchassistant.MainActivity
import fi.eport.searchassistant.R
import fi.eport.searchassistant.SearchAssistantApp
import kotlinx.datetime.Instant

/// Foreground service that owns the FusedLocationProviderClient
/// subscription while the user has Share Location (or Record Path)
/// active. A persistent notification is required from API 26+ to keep
/// the process alive when the screen is off; tapping it returns to
/// the SearchScreen.
class LocationService : Service() {

    private lateinit var fused: com.google.android.gms.location.FusedLocationProviderClient
    private lateinit var controller: LocationController

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val loc = result.lastLocation ?: return
            controller.publishFix(
                GeoFix(
                    lng = loc.longitude,
                    lat = loc.latitude,
                    accuracyMeters = loc.accuracy.toDouble(),
                    headingDegrees = if (loc.hasBearing()) loc.bearing.toDouble() else null,
                    timestamp = Instant.fromEpochMilliseconds(loc.time),
                )
            )
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureChannel(this)
        controller = (application as SearchAssistantApp).container.locationController
        fused = LocationServices.getFusedLocationProviderClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundIfPermitted()

        if (!hasFinePermission()) {
            controller.setError("Location permission is off — enable it in Settings.")
            stopSelf()
            return START_NOT_STICKY
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1_000L)
            .setMinUpdateDistanceMeters(5f)
            .setMinUpdateIntervalMillis(1_000L)
            .setWaitForAccurateLocation(false)
            .build()

        try {
            fused.requestLocationUpdates(request, callback, Looper.getMainLooper())
            controller.setWatching(true)
        } catch (sec: SecurityException) {
            controller.setError("Location permission denied.")
            stopSelf()
        }
        return START_STICKY
    }

    private fun startForegroundIfPermitted() {
        val notif = buildNotification(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun hasFinePermission(): Boolean = ContextCompat.checkSelfPermission(
        this, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

    override fun onDestroy() {
        runCatching { fused.removeLocationUpdates(callback) }
        controller.setWatching(false)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val NOTIF_ID = 4242
        private const val CHANNEL_ID = "location_sharing"

        fun start(context: Context) {
            val intent = Intent(context, LocationService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, LocationService::class.java))
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val mgr = context.getSystemService(NotificationManager::class.java)
            if (mgr.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Location sharing",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Persistent notification shown while sharing your location."
                setShowBadge(false)
            }
            mgr.createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context): Notification {
            val pi = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("Sharing your location")
                .setContentText("Search Assistant is sharing your location with your group.")
                .setContentIntent(pi)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .build()
        }
    }
}
