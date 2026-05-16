import type { Point, Polygon, LineString } from 'geojson'

export interface CreateSearchRequest {
  title: string
  centerLng?: number | null
  centerLat?: number | null
  zoom?: number | null
}

export interface CreateSearchResponse {
  slug: string
  ownerToken: string
  joinUrl: string
}

export interface JoinRequest { displayName: string }
export interface JoinResponse {
  participantId: string
  sessionToken: string
  color: string
}

export interface ParticipantDto {
  id: string
  displayName: string
  color: string
  joinedAt: string
  lastSeenAt: string
  lastPosition: Point | null
}

export interface AreaDto {
  id: string
  createdByParticipantId: string
  createdAt: string
  geometry: Polygon
}

export interface PathDto {
  id: string
  participantId: string
  startedAt: string
  endedAt: string | null
  geometry: LineString
}

export interface SearchSnapshotDto {
  slug: string
  title: string
  createdAt: string
  expiresAt: string | null
  center: Point | null
  defaultZoom: number
  participants: ParticipantDto[]
  areas: AreaDto[]
  paths: PathDto[]
}

export interface PositionUpdateDto {
  participantId: string
  lng: number
  lat: number
  accuracyMeters: number
  headingDegrees: number | null
  recordedAt: string
}
