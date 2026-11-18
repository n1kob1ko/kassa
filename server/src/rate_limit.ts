const DEFAULT_MAX_KEYS = 50_000;

/**
 * Zählt Ereignisse pro Schlüssel in einem gleitenden Zeitfenster, nur im Speicher.
 * Eine Instanz gehört zu einer App (in buildApp anlegen), nie in eine Modul-Variable.
 * Höchstens `maxKeys` Schlüssel: Ist die Liste voll, gilt ein neuer Schlüssel als über der Grenze,
 * bis alte ablaufen. So wächst der Speicher nie über eine feste Größe.
 */
export class SlidingWindow {
  /** Treffer pro Schlüssel, aufsteigend. Die Reihenfolge der Map folgt dem letzten Treffer, der älteste zuerst. */
  private readonly hits = new Map<string, number[]>();
  private readonly maxKeys: number;

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
    opts: { maxKeys?: number } = {},
  ) {
    this.maxKeys = opts.maxKeys ?? DEFAULT_MAX_KEYS;
  }

  /** Wie viele Schlüssel gerade gespeichert sind. */
  get size(): number {
    return this.hits.size;
  }

  /** Zählt einen Treffer (reserviert einen Platz). `false` heißt Grenze erreicht: Dann wird nichts gezählt. */
  hit(key: string, now: Date): boolean {
    this.dropExpired(now);
    const list = this.current(key, now);
    if (list.length >= this.limit) return false;
    if (list.length === 0 && this.hits.size >= this.maxKeys) return false;
    list.push(now.getTime());
    // Ans Ende stellen: Die Map bleibt nach dem letzten Treffer geordnet.
    this.hits.delete(key);
    this.hits.set(key, list);
    return true;
  }

  /** Gibt einen mit hit(key, at) reservierten Treffer zurück. */
  release(key: string, at: Date): void {
    const list = this.hits.get(key);
    if (!list) return;
    const i = list.lastIndexOf(at.getTime());
    list.splice(i >= 0 ? i : list.length - 1, 1);
    if (list.length === 0) this.hits.delete(key);
  }

  /** Millisekunden, bis hit(key) wieder zählt. 0 heißt: die Grenze ist nicht erreicht. */
  retryAfterMs(key: string, now: Date): number {
    this.dropExpired(now);
    const list = this.current(key, now);
    if (list.length >= this.limit) {
      // Wieder frei, sobald so viele alte Treffer herausgefallen sind, dass einer Platz hat.
      return list[list.length - this.limit]! + this.windowMs - now.getTime();
    }
    if (list.length === 0 && this.hits.size >= this.maxKeys) {
      // Voll: frei, sobald der Schlüssel mit dem ältesten letzten Treffer abläuft.
      const oldest = this.hits.values().next().value!;
      return Math.max(oldest[oldest.length - 1]! + this.windowMs - now.getTime(), 1);
    }
    return 0;
  }

  /** Die Treffer eines Schlüssels im Fenster. Ein Treffer zählt, solange er jünger als windowMs ist. */
  private current(key: string, now: Date): number[] {
    const list = this.hits.get(key);
    if (!list) return [];
    const from = now.getTime() - this.windowMs;
    const kept = list.filter((t) => t > from);
    if (kept.length === 0) this.hits.delete(key);
    else this.hits.set(key, kept);
    return kept;
  }

  /** Entfernt von vorn alle Schlüssel, deren letzter Treffer aus dem Fenster gefallen ist. */
  private dropExpired(now: Date): void {
    const from = now.getTime() - this.windowMs;
    for (const [key, list] of this.hits) {
      if (list[list.length - 1]! > from) break;
      this.hits.delete(key);
    }
  }
}
