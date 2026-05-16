// localStorage-backed lookup of per-slug session tokens (and the creator's owner tokens).
const SESSION_PREFIX = 'sa:session:'
const OWNER_PREFIX = 'sa:owner:'

export function getSessionToken(slug: string): string | null {
  return localStorage.getItem(SESSION_PREFIX + slug)
}

export function setSessionToken(slug: string, token: string): void {
  localStorage.setItem(SESSION_PREFIX + slug, token)
}

export function clearSessionToken(slug: string): void {
  localStorage.removeItem(SESSION_PREFIX + slug)
}

export function setOwnerToken(slug: string, token: string): void {
  localStorage.setItem(OWNER_PREFIX + slug, token)
}

export function getOwnerToken(slug: string): string | null {
  return localStorage.getItem(OWNER_PREFIX + slug)
}
