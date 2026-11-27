/**
 * Zählt je Adresse VERSCHIEDENE Fehlversuche in einem gleitenden Fenster, nur im Speicher; eine Instanz je App.
 *
 * - Gesperrt ist eine Adresse nur, wenn IHRE Liste voll ist (`max` verschiedene Fehlversuche im Fenster).
 * - Gezählt wird erst nach einem Fehlversuch. Derselbe Fehlversuch (gleicher Prüfwert) noch einmal zählt nicht: ein
 *   Kunde, der einen noch nicht angekommenen Bon zehnmal neu lädt, sperrt seine Adresse nicht.
 * - Gespeichert wird je Fehlversuch nur ein kurzer Prüfwert (vom Aufrufer), nie der Schlüssel selbst.
 * - Speicher begrenzt: höchstens `maxKeys` Adressen mit je höchstens `max` Einträgen. Abgelaufene fallen bei jedem
 *   Aufruf heraus; ist die Tabelle trotzdem voll, fällt die Adresse mit dem ältesten letzten Fehlversuch heraus, statt
 *   neue Adressen abzuweisen.
 */
export class MissLimiter {
  /** Je Adresse die Fehlversuche, aufsteigend nach Zeit. Die Map ist nach dem letzten Fehlversuch geordnet, ältester zuerst. */
  private readonly misses = new Map<string, { hash: string; at: number }[]>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
    private readonly maxKeys = 50_000,
  ) {}

  /** Wie viele Adressen gerade gespeichert sind. */
  get size(): number {
    return this.misses.size;
  }

  /** Millisekunden, bis die Adresse wieder darf; 0 heißt: nicht gesperrt. */
  blockedMs(key: string, now: Date): number {
    this.dropExpired(now);
    const list = this.current(key, now);
    if (list.length < this.max) return 0;
    return Math.max(list[list.length - this.max]!.at + this.windowMs - now.getTime(), 1);
  }

  /** Ein Fehlversuch mit dem Prüfwert [hash]. Schon gezählt oder Liste voll: nichts ändert sich. */
  miss(key: string, hash: string, now: Date): void {
    this.dropExpired(now);
    const list = this.current(key, now);
    if (list.some((m) => m.hash === hash) || list.length >= this.max) return;
    list.push({ hash, at: now.getTime() });
    // Ans Ende stellen: die Map bleibt nach dem letzten Fehlversuch geordnet.
    this.misses.delete(key);
    this.misses.set(key, list);
    while (this.misses.size > this.maxKeys) {
      this.misses.delete(this.misses.keys().next().value!);
    }
  }

  private current(key: string, now: Date): { hash: string; at: number }[] {
    const list = this.misses.get(key);
    if (!list) return [];
    const from = now.getTime() - this.windowMs;
    const kept = list.filter((m) => m.at > from);
    if (kept.length === 0) this.misses.delete(key);
    else if (kept.length !== list.length) this.misses.set(key, kept);
    return kept;
  }

  /** Entfernt von vorn alle Adressen, deren letzter Fehlversuch aus dem Fenster gefallen ist. */
  private dropExpired(now: Date): void {
    const from = now.getTime() - this.windowMs;
    for (const [key, list] of this.misses) {
      if (list[list.length - 1]!.at > from) break;
      this.misses.delete(key);
    }
  }
}
