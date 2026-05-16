package fi.eport.searchassistant.location

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow

/// Singleton bridge between [LocationService] (writer) and the
/// ViewModel (reader). Decouples the service lifecycle from the
/// activity lifecycle — if the user backgrounds the app while
/// recording, fixes still arrive in the flow and the VM can keep
/// flushing them to the server.
class LocationController {
    private val _fixes = MutableSharedFlow<GeoFix>(extraBufferCapacity = 64)
    val fixes: SharedFlow<GeoFix> = _fixes.asSharedFlow()

    private val _isWatching = MutableStateFlow(false)
    val isWatching: StateFlow<Boolean> = _isWatching.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    fun publishFix(fix: GeoFix) {
        _fixes.tryEmit(fix)
    }

    fun setWatching(value: Boolean) {
        _isWatching.value = value
        if (value) _lastError.value = null
    }

    fun setError(message: String?) {
        _lastError.value = message
    }
}
