import type { StyleSpecification } from 'maplibre-gl'

// Minimal OSM raster style. Fine for dev; before any real load, swap in a MapTiler
// key or self-hosted tileserver-gl (per plan, "Open questions / decisions deferred").
export const osmRasterStyle: StyleSpecification = {
  version: 8,
  sources: {
    osm: {
      type: 'raster',
      tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
      tileSize: 256,
      maxzoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    },
  },
  layers: [
    {
      id: 'osm',
      type: 'raster',
      source: 'osm',
    },
  ],
}
