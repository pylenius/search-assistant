import type { Polygon } from 'geojson'
import type {
  AreaDto,
  CreateSearchRequest,
  CreateSearchResponse,
  JoinRequest,
  JoinResponse,
  ParticipantDto,
  PathDto,
  SearchSnapshotDto,
} from '../types/api'

export const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:5080'

export class ApiError extends Error {
  status: number
  body?: unknown
  constructor(status: number, message: string, body?: unknown) {
    super(message)
    this.status = status
    this.body = body
  }
}

async function request<T>(path: string, init: RequestInit = {}, sessionToken?: string): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init.headers as Record<string, string> ?? {}),
  }
  if (sessionToken) headers['X-Session-Token'] = sessionToken

  const res = await fetch(API_BASE + path, { ...init, headers })
  if (!res.ok) {
    let body: unknown
    try { body = await res.json() } catch { body = await res.text() }
    throw new ApiError(res.status, `${init.method ?? 'GET'} ${path} → ${res.status}`, body)
  }
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

export const api = {
  createSearch(body: CreateSearchRequest) {
    return request<CreateSearchResponse>('/api/searches', {
      method: 'POST', body: JSON.stringify(body),
    })
  },
  getSearch(slug: string) {
    return request<SearchSnapshotDto>(`/api/searches/${encodeURIComponent(slug)}`)
  },
  joinSearch(slug: string, body: JoinRequest) {
    return request<JoinResponse>(`/api/searches/${encodeURIComponent(slug)}/join`, {
      method: 'POST', body: JSON.stringify(body),
    })
  },
  me(slug: string, sessionToken: string) {
    return request<ParticipantDto>(`/api/searches/${encodeURIComponent(slug)}/me`,
      {}, sessionToken)
  },
  addArea(
    slug: string,
    body: { geometry: Polygon; title?: string | null; color?: string | null },
    sessionToken: string,
  ) {
    return request<AreaDto>(`/api/searches/${encodeURIComponent(slug)}/areas`, {
      method: 'POST', body: JSON.stringify(body),
    }, sessionToken)
  },
  removeArea(slug: string, areaId: string, sessionToken: string) {
    return request<void>(`/api/searches/${encodeURIComponent(slug)}/areas/${areaId}`, {
      method: 'DELETE',
    }, sessionToken)
  },
  startPath(slug: string, points: [number, number][], sessionToken: string) {
    return request<PathDto>(`/api/searches/${encodeURIComponent(slug)}/paths`, {
      method: 'POST', body: JSON.stringify({ points }),
    }, sessionToken)
  },
  appendToPath(slug: string, pathId: string, points: [number, number][], sessionToken: string) {
    return request<PathDto>(`/api/searches/${encodeURIComponent(slug)}/paths/${pathId}`, {
      method: 'PATCH', body: JSON.stringify({ points }),
    }, sessionToken)
  },
  finalizePath(slug: string, pathId: string, sessionToken: string) {
    return request<PathDto>(`/api/searches/${encodeURIComponent(slug)}/paths/${pathId}`, {
      method: 'PATCH', body: JSON.stringify({ finalize: true }),
    }, sessionToken)
  },
  updateSearch(slug: string, body: { title?: string; expiresAt?: string | null }, ownerToken: string) {
    return ownerRequest<{ title: string; expiresAt: string | null }>(
      `/api/searches/${encodeURIComponent(slug)}`,
      { method: 'PATCH', body: JSON.stringify(body) },
      ownerToken,
    )
  },
  deleteSearch(slug: string, ownerToken: string) {
    return ownerRequest<void>(
      `/api/searches/${encodeURIComponent(slug)}`,
      { method: 'DELETE' },
      ownerToken,
    )
  },
  clearPaths(slug: string, ownerToken: string) {
    return ownerRequest<{ cleared: number }>(
      `/api/searches/${encodeURIComponent(slug)}/paths`,
      { method: 'DELETE' },
      ownerToken,
    )
  },
}

async function ownerRequest<T>(path: string, init: RequestInit, ownerToken: string): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Owner-Token': ownerToken,
    ...(init.headers as Record<string, string> ?? {}),
  }
  const res = await fetch(API_BASE + path, { ...init, headers })
  if (!res.ok) {
    let body: unknown
    try { body = await res.json() } catch { body = await res.text() }
    throw new ApiError(res.status, `${init.method ?? 'GET'} ${path} → ${res.status}`, body)
  }
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

export const HUB_URL = API_BASE + (import.meta.env.VITE_HUB_PATH ?? '/hub/search')
