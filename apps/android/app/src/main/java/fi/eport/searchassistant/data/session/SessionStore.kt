package fi.eport.searchassistant.data.session

import android.content.Context
import android.content.SharedPreferences

/// Per-slug auth tokens. SharedPreferences is fine here — these are
/// link-derived session secrets, not high-value credentials; the link-
/// trust threat model is identical to the iOS UserDefaults storage.
/// Keys mirror the iOS app and the web localStorage (`sa.session.{slug}`,
/// `sa.owner.{slug}`) so the prefix is easy to grep for.
class SessionStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("session_store", Context.MODE_PRIVATE)

    // Session token (participant) -----------------------------------

    fun sessionToken(slug: String): String? = prefs.getString(sessionKey(slug), null)

    fun setSessionToken(token: String, slug: String) {
        prefs.edit().putString(sessionKey(slug), token).apply()
    }

    fun clearSessionToken(slug: String) {
        prefs.edit().remove(sessionKey(slug)).apply()
    }

    // Owner token (creator) ------------------------------------------

    fun ownerToken(slug: String): String? = prefs.getString(ownerKey(slug), null)

    fun setOwnerToken(token: String, slug: String) {
        prefs.edit().putString(ownerKey(slug), token).apply()
    }

    private fun sessionKey(slug: String) = "sa.session.$slug"
    private fun ownerKey(slug: String) = "sa.owner.$slug"
}
