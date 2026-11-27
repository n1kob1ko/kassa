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
  /** Je Adresse die Prüfwerte der Anfragen, die gerade nachsehen, mit ihrer Anzahl. Leer, sobald keine mehr läuft. */
  private readonly pending = new Map<string, Map<string, number>>();

  constructor(
    private readonly max: number,
    private readonly windowMs: number,
    private readonly maxKeys = 50_000,
  ) {}

  /** Wie viele Adressen gerade Fehlversuche gespeichert haben. */
  get size(): number {
    return this.misses.size;
  }

  /** Wie viele Adressen gerade Anfragen haben, die nachsehen. */
  get pendingSize(): number {
    return this.pending.size;
  }

  /**
   * Reserviert vor dem Nachsehen einen Platz für den Prüfwert [hash]: laufende Anfragen zählen mit. `false`, wenn
   * gespeicherte und laufende verschiedene Prüfwerte zusammen schon `max` erreichen; dann nichts reservieren. Derselbe
   * Prüfwert, schon gespeichert oder schon laufend, braucht keinen zweiten Platz und darf nachsehen. Jedes `true` muss mit
   * genau einem `release` oder `record` enden.
   */
  reserve(key: string, hash: string, now: Date): boolean {
    this.dropExpired(now);
    const list = this.current(key, now);
    const running = this.pending.get(key) ?? new Map<string, number>();
    const known = list.some((m) => m.hash === hash) || running.has(hash);
    if (!known && list.length + running.size >= this.max) return false;
    running.set(hash, (running.get(hash) ?? 0) + 1);
    this.pending.set(key, running);
    this.evict();
    return true;
  }

  /** Gibt eine Reservierung zurück, ohne etwas zu zählen (Treffer oder Fehler des Servers). */
  release(key: string, hash: string): void {
    const running = this.pending.get(key);
    const n = running?.get(hash);
    if (!running || n === undefined) return;
    if (n > 1) running.set(hash, n - 1);
    else running.delete(hash);
    if (running.size === 0) this.pending.delete(key);
  }

  /** Macht aus einer Reservierung einen gespeicherten Fehlversuch. */
  record(key: string, hash: string, now: Date): void {
    this.miss(key, hash, now);
    this.release(key, hash);
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
    this.evict();
  }

  /**
   * Hält die Tabelle in der Grenze: Adressen mit Fehlversuchen und Adressen mit laufenden Anfragen zählen zusammen
   * gegen `maxKeys`. Ist es zu viel, fällt die Adresse mit dem ältesten gespeicherten Fehlversuch heraus. Laufende
   * Anfragen fallen nie heraus: sie enden mit release oder record von selbst, ihre Zahl ist durch die gleichzeitig
   * laufenden Anfragen begrenzt (je Adresse höchstens `max` Prüfwerte). Fällt eine Adresse heraus, während bei ihr noch
   * Anfragen laufen, bleiben deren Reservierungen und bremsen weiter.
   */
  private evict(): void {
    while (this.misses.size > 0 && this.misses.size + this.pending.size > this.maxKeys) {
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
