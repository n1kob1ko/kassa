/**
 * Zählt Ereignisse pro Schlüssel in einem gleitenden Zeitfenster, nur im Speicher.
 * Eine Instanz gehört zu einer App (in buildApp anlegen), nie in eine Modul-Variable.
 */
export class SlidingWindow {
  private readonly hits = new Map<string, number[]>();
  private lastSweep = 0;

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
  ) {}

  /** Zählt einen Treffer. `false` heißt Grenze erreicht: Dann wird nichts gezählt. */
  hit(key: string, now: Date): boolean {
    this.sweep(now);
    const list = this.current(key, now);
    if (list.length >= this.limit) return false;
    list.push(now.getTime());
    this.hits.set(key, list);
    return true;
  }

  /** Millisekunden, bis wieder ein Treffer zählt. 0 heißt: die Grenze ist nicht erreicht. */
  retryAfterMs(key: string, now: Date): number {
    const list = this.current(key, now);
    if (list.length < this.limit) return 0;
    // Wieder frei, sobald so viele alte Treffer herausgefallen sind, dass einer Platz hat.
    return list[list.length - this.limit]! + this.windowMs - now.getTime();
  }

  /** Die Treffer im Fenster, aufsteigend. Ein Treffer zählt, solange er jünger als windowMs ist. */
  private current(key: string, now: Date): number[] {
    const list = this.hits.get(key);
    if (!list) return [];
    const from = now.getTime() - this.windowMs;
    const kept = list.filter((t) => t > from);
    if (kept.length === 0) this.hits.delete(key);
    else this.hits.set(key, kept);
    return kept;
  }

  /** Räumt höchstens einmal pro Fenster alle Schlüssel ab, damit nie wieder benutzte Schlüssel nicht liegen bleiben. */
  private sweep(now: Date): void {
    if (now.getTime() - this.lastSweep < this.windowMs) return;
    this.lastSweep = now.getTime();
    for (const key of [...this.hits.keys()]) this.current(key, now);
  }
}
