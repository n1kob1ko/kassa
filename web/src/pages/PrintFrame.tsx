import { useEffect, useState, type ReactNode } from 'react';
import { flushSync } from 'react-dom';
import { dateText, timeText } from '../format';
import { Button } from '../ui/Button';
import { PrinterIcon } from '../ui/icons';
import { useBusinessContext } from './BusinessLayout';

/** Öffnet den Druckdialog des Browsers; dort lässt sich das Blatt auch als PDF sichern. */
export function PrintButton() {
  return (
    <Button variant="secondary" onClick={() => window.print()}>
      <PrinterIcon size={18} />
      Drucken
    </Button>
  );
}

/**
 * Rahmen eines Blatts für den Druck (print.css): oben Betrieb und Titel, unten "Erstellt am". Beides steht nur im
 * Druck; am Bildschirm trägt der Kopf des Blatts den Titel. Die Zeit ist die des Druckens (`beforeprint`).
 */
export function PrintFrame({ title, children }: { title: string; children: ReactNode }) {
  const { business } = useBusinessContext().detail;
  const [at, setAt] = useState(() => new Date());
  useEffect(() => {
    // Synchron, damit der Druck schon die neue Zeit zeigt.
    const update = () => flushSync(() => setAt(new Date()));
    window.addEventListener('beforeprint', update);
    return () => window.removeEventListener('beforeprint', update);
  }, []);
  return (
    <>
      <div className="print-only print-head">
        <p className="print-business">{business.name}</p>
        <p className="print-title">{title}</p>
      </div>
      {children}
      <p className="print-only print-foot">
        Erstellt am {dateText(at)} um {timeText(at)}
      </p>
    </>
  );
}
