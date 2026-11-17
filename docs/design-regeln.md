# Design-Regeln von Niko

Niko hat am 17.11.2026 zwei Listen geschickt, mit dem Satz "diese regeln noch wichtig". Sie gelten für jede Oberfläche von Kassa, zusätzlich zu `PRODUCT.md` und später `DESIGN.md`.

## Liste 1: 20 Principles of UX & Animation

Squash & stretch, Anticipation wind-up, Staging the focus, Pose to pose, Follow through, Slow in & slow out, Moving in arcs, Secondary action, Snappy timing, Exaggerated feedback, Solid drawing in 3D, Overall appeal, Fitts's law, Bigger hit areas, Hick's law, Miller's law, Doherty threshold, Postel's law, Jakob's law, Frequency of use.

## Liste 2: technische Bedien-Regeln

Skeleton loaders, Optimistic updates, Command menu, Shortcut hints, Undo toasts, Stale-while-revalidate, Pre-rendering, BlurHash placeholders, View transitions, Swipe-to-dismiss sheets, Interruptible animations, Predictive back, Hit slop, Safe area insets, One-time code autofill, Tabular numbers, Balanced headlines, Continuous corners, Idempotency keys, Amazon safe triangle.

## Einordnung für eine Kasse

Diese Einordnung stammt von Claude, nicht von Niko.

- **Kern für den Kassenbildschirm:** Fitts's law und große Tippflächen samt Hit slop. Hick's law (wenige Kategorien). Frequency of use (Favoriten zuerst). Jakob's law (Aufbau wie bekannte Kassen). Doherty threshold (Reaktion unter 400 ms). Snappy timing. Exaggerated feedback beim Tippen. Tabular numbers für Preise. Interruptible animations.
- **Technik:** Optimistic updates (der Bon ändert sich sofort). Undo toasts statt Rückfragen (zum Beispiel "Bon leeren"). Idempotency keys bei Kartenzahlung und beim Erstellen eines Bons (kein doppeltes Abbuchen, kein doppelter Bon). Stale-while-revalidate für die Speisekarte. Predictive back und Safe area insets auf Android. Skeleton loaders in der Browser-Verwaltung.
- **Eher für die Browser-Verwaltung als für die Theke:** Command menu, Shortcut hints, Amazon safe triangle, One-time code autofill (Anmeldung), BlurHash (für Artikelfotos).
- **An der Theke bewusst sparsam:** Squash & stretch, Anticipation, Follow through, Moving in arcs und Secondary action nur als kurzes Tipp-Feedback. An der Kasse darf keine Bewegung auf sich warten lassen.
