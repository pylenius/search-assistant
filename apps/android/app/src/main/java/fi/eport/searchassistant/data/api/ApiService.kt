package fi.eport.searchassistant.data.api

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import java.util.UUID

/// Retrofit service for the 12 REST endpoints exposed by the .NET API.
/// Auth-bearing endpoints take the token as an @Header rather than going
/// through an interceptor — keeps the per-call surface explicit and
/// avoids accidentally leaking the session token onto unauthenticated
/// calls.
interface ApiService {
    // Search lifecycle ------------------------------------------------

    @POST("api/searches")
    suspend fun createSearch(@Body body: CreateSearchRequest): CreateSearchResponse

    @GET("api/searches/{slug}")
    suspend fun getSearch(@Path("slug") slug: String): SearchSnapshotDto

    @POST("api/searches/{slug}/join")
    suspend fun joinSearch(
        @Path("slug") slug: String,
        @Body body: JoinRequest,
    ): JoinResponse

    @GET("api/searches/{slug}/me")
    suspend fun me(
        @Path("slug") slug: String,
        @Header("X-Session-Token") sessionToken: String,
    ): ParticipantDto

    // Areas / paths (participant-authed) -----------------------------

    @POST("api/searches/{slug}/areas")
    suspend fun addArea(
        @Path("slug") slug: String,
        @Body body: AddAreaRequest,
        @Header("X-Session-Token") sessionToken: String,
    ): AreaDto

    @DELETE("api/searches/{slug}/areas/{areaId}")
    suspend fun removeArea(
        @Path("slug") slug: String,
        @Path("areaId") areaId: UUID,
        @Header("X-Session-Token") sessionToken: String,
    )

    @POST("api/searches/{slug}/paths")
    suspend fun startPath(
        @Path("slug") slug: String,
        @Body body: StartPathRequest,
        @Header("X-Session-Token") sessionToken: String,
    ): PathDto

    @PATCH("api/searches/{slug}/paths/{pathId}")
    suspend fun updatePath(
        @Path("slug") slug: String,
        @Path("pathId") pathId: UUID,
        @Body body: UpdatePathRequest,
        @Header("X-Session-Token") sessionToken: String,
    ): PathDto

    // Manage (owner-authed) -----------------------------------------

    @PATCH("api/searches/{slug}")
    suspend fun updateSearch(
        @Path("slug") slug: String,
        @Body body: UpdateSearchRequest,
        @Header("X-Owner-Token") ownerToken: String,
    ): UpdateSearchResponse

    @DELETE("api/searches/{slug}")
    suspend fun deleteSearch(
        @Path("slug") slug: String,
        @Header("X-Owner-Token") ownerToken: String,
    )

    @DELETE("api/searches/{slug}/paths")
    suspend fun clearPaths(
        @Path("slug") slug: String,
        @Header("X-Owner-Token") ownerToken: String,
    ): ClearPathsResponse
}
