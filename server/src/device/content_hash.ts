import { createHash } from 'node:crypto';

/** JSON mit sortierten Schlüsseln, Listen behalten ihre Reihenfolge. */
function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (typeof value === 'object' && value !== null) {
    const o = value as Record<string, unknown>;
    return `{${Object.keys(o)
      .filter((k) => o[k] !== undefined)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canonical(o[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value) ?? 'null';
}

/** SHA-256 über das JSON mit sortierten Schlüsseln: gleicher Inhalt, gleiche Prüfsumme, egal in welcher Reihenfolge. */
export function contentHash(value: unknown): Buffer {
  return createHash('sha256').update(canonical(value)).digest();
}
