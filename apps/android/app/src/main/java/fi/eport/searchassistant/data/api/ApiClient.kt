package fi.eport.searchassistant.data.api

import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import fi.eport.searchassistant.AppConfig
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.HttpException
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

/// Wraps Retrofit + OkHttp. Singleton lifecycle via [AppContainer].
class ApiClient(
    val json: Json = defaultJson,
) {
    private val okHttp: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .addInterceptor(
            HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BASIC
            }
        )
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(AppConfig.API_BASE_URL)
        .client(okHttp)
        .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
        .build()

    val service: ApiService = retrofit.create(ApiService::class.java)

    companion object {
        /// Shared JSON config — reused by SignalRService in step 6 so the
        /// hub uses the same Instant + Uuid serializers as REST.
        val defaultJson: Json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true   // keep the "type":"Point" field on GeoJSON geometries
            explicitNulls = false
        }
    }
}

/// Convenience: extract the HTTP status code from a Retrofit exception,
/// or null if the failure wasn't a server response.
val Throwable.httpStatus: Int?
    get() = (this as? HttpException)?.code()
