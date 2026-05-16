import {
  HubConnection,
  HubConnectionBuilder,
  HubConnectionState,
  LogLevel,
} from '@microsoft/signalr'
import { HUB_URL } from './apiClient'
import type {
  AreaDto, ParticipantDto, PathDto, PositionUpdateDto,
} from '../types/api'

export interface SearchUpdated { title: string; expiresAt: string | null }

export interface SearchHubHandlers {
  onParticipantJoined: (p: ParticipantDto) => void
  onParticipantLeft: (participantId: string) => void
  onPositionUpdated: (u: PositionUpdateDto) => void
  onAreaAdded: (a: AreaDto) => void
  onAreaRemoved: (areaId: string) => void
  onPathStarted: (p: PathDto) => void
  onPathUpdated: (p: PathDto) => void
  onPathFinalized: (pathId: string) => void
  onSearchUpdated: (u: SearchUpdated) => void
  onSearchEnded: (slug: string) => void
}

export class SearchHubClient {
  private connection: HubConnection | null = null

  async connect(slug: string, sessionToken: string, handlers: SearchHubHandlers): Promise<void> {
    if (this.connection) return

    const conn = new HubConnectionBuilder()
      .withUrl(HUB_URL)
      .withAutomaticReconnect()
      .configureLogging(LogLevel.Warning)
      .build()

    conn.on('ParticipantJoined', handlers.onParticipantJoined)
    conn.on('ParticipantLeft', handlers.onParticipantLeft)
    conn.on('PositionUpdated', handlers.onPositionUpdated)
    conn.on('AreaAdded', handlers.onAreaAdded)
    conn.on('AreaRemoved', handlers.onAreaRemoved)
    conn.on('PathStarted', handlers.onPathStarted)
    conn.on('PathUpdated', handlers.onPathUpdated)
    conn.on('PathFinalized', handlers.onPathFinalized)
    conn.on('SearchUpdated', handlers.onSearchUpdated)
    conn.on('SearchEnded', handlers.onSearchEnded)

    await conn.start()
    await conn.invoke('JoinSearch', slug, sessionToken)
    this.connection = conn
  }

  async sendPosition(lng: number, lat: number, accuracyMeters: number, headingDegrees: number | null) {
    if (!this.connection || this.connection.state !== HubConnectionState.Connected) return
    await this.connection.invoke('SendPosition', lng, lat, accuracyMeters, headingDegrees)
  }

  async disconnect() {
    if (this.connection) {
      await this.connection.stop()
      this.connection = null
    }
  }

  get state(): HubConnectionState | 'disconnected' {
    return this.connection?.state ?? 'disconnected'
  }
}
