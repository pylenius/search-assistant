package fi.eport.searchassistant.ui.search

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.google.android.gms.maps.model.BitmapDescriptor
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import fi.eport.searchassistant.util.toComposeColor

/// Tiny cache of pre-rendered marker bitmaps keyed by `(color, stale)`.
/// We hit it on every PositionUpdated dispatch, so re-rasterising on
/// every call would be wasteful. The cache lives at app scope; with
/// 12 palette colors × 2 stale states this tops out at 24 entries.
object MarkerBitmaps {
    private val cache = mutableMapOf<String, BitmapDescriptor>()

    fun circle(colorHex: String, stale: Boolean): BitmapDescriptor {
        val key = "$colorHex|${if (stale) "s" else "f"}"
        return cache.getOrPut(key) { render(colorHex.toComposeColor(), stale) }
    }

    private fun render(color: Color, stale: Boolean): BitmapDescriptor {
        val sizePx = 48  // ~16dp at mdpi; GoogleMap scales for density
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(0, PorterDuff.Mode.CLEAR)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Outer white ring for legibility
        paint.color = android.graphics.Color.WHITE
        paint.style = Paint.Style.FILL
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f, paint)

        // Inner filled circle in participant color (faded if stale)
        val argb = if (stale) {
            val c = color.toArgb()
            android.graphics.Color.argb(
                140,
                android.graphics.Color.red(c),
                android.graphics.Color.green(c),
                android.graphics.Color.blue(c),
            )
        } else color.toArgb()
        paint.color = argb
        canvas.drawCircle(sizePx / 2f, sizePx / 2f, sizePx / 2f - 5f, paint)

        return BitmapDescriptorFactory.fromBitmap(bitmap)
    }
}
