export function slugFromPath(path: string): string | null {
  const trimmed = path.replace(/\/+$/, '')
  const parts = trimmed.split('/').filter(Boolean)
  if (parts.length !== 1) return null
  return parts[0]
}
