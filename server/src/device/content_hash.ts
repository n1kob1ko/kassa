import { createHash } from 'node:crypto';

/** JSON mit sortierten Schlüsseln, Listen behalten ihre Reihenfolge. */
function canonical(value: unknown): string {
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) throw new TypeError('Ungültige Zeit lässt sich nicht hashen');
    return JSON.stringify(value.toISOString());
  }
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (typeof value === 'object' && value !== null) {
    const o = value as Record<string, unknown>;
    return `{${Object.keys(o)
      .filter((k) => o[k] !== undefined)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canonical(o[k])}`)
      .join(',')}}`;
  }
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return JSON.stringify(value);
  if (typeof value === 'number' && Number.isFinite(value)) return JSON.stringify(value);
  throw new TypeError(`Ein Wert vom Typ ${typeof value} lässt sich nicht hashen`);
}

/** SHA-256 über das JSON mit sortierten Schlüsseln: gleicher Inhalt, gleiche Prüfsumme, egal in welcher Reihenfolge. */
export function contentHash(value: unknown): Buffer {
  return createHash('sha256').update(canonical(value)).digest();
}
