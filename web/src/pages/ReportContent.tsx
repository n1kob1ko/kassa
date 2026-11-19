import { deviceName, devicesOf, errorOf, serverKindText, type Report } from '../api/reports';
import { Button } from '../ui/Button';
import { AlertIcon, CheckCircleIcon, CopyIcon } from '../ui/icons';
import { toast } from '../ui/Toast';
import styles from './ReportContent.module.css';

async function copy(text: string): Promise<void> {
  try {
    await navigator.clipboard.writeText(text);
    toast.show('Kopiert.');
  } catch {
    toast.show('Kopieren geht hier nicht. Markier den Text im Kasten und kopier ihn selbst.');
  }
}

/** Fester Text in fester Schrift, der in seinem Kasten scrollt (nie die Seite), mit "Kopieren" darüber. */
function CodeBlock({ title, copyLabel, text }: { title: string; copyLabel: string; text: string }) {
  return (
    <div className={styles.block}>
      <div className={styles.blockHead}>
        <h3 className={styles.blockTitle}>{title}</h3>
        <Button variant="quiet" className={styles.copy} aria-label={copyLabel} onClick={() => void copy(text)}>
          <CopyIcon size={18} />
          Kopieren
        </Button>
      </div>
      {/* Als Kindtext gesetzt: React macht daraus nie HTML. Fokussierbar, damit der Kasten mit der Tastatur scrollt. */}
      <pre className={styles.code} tabIndex={0} role="region" aria-label={title}>
        {text}
      </pre>
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.fact}>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

/**
 * Was ein Bericht enthält, aufgeklappt unter seiner Zeile: beim Fehler Art, Meldung und Aufrufliste, beim
 * Geräte-Test die Geräte, beim Server die Art in Worten und den Inhalt. Alles nur als Text.
 */
export function ReportContent({ report }: { report: Report }) {
  if (report.source === 'server') {
    return (
      <div className={styles.content}>
        <p className={styles.lead}>{serverKindText(report.kind)}</p>
        <CodeBlock title="Inhalt" copyLabel="Inhalt kopieren" text={JSON.stringify(report.content, null, 2)} />
      </div>
    );
  }

  const error = report.kind === 'error' ? errorOf(report.content) : null;
  if (error) {
    return (
      <div className={styles.content}>
        <dl className={styles.facts}>
          <Fact label="Fehlerart" value={error.type} />
          {error.message && <Fact label="Meldung" value={error.message} />}
          {report.deviceModel && <Fact label="Gerät" value={report.deviceModel} />}
        </dl>
        <CodeBlock title="Aufrufliste" copyLabel="Aufrufliste kopieren" text={error.stack} />
      </div>
    );
  }

  const devices = report.kind === 'device_test' ? devicesOf(report.content) : null;
  if (devices) {
    return (
      <div className={styles.content}>
        <ul className={styles.devices} aria-label="Geräte">
          {devices.map((d, i) => (
            <li key={i} className={styles.device}>
              <span className={styles.deviceHead}>
                <span className={styles.deviceName}>{deviceName(d.device)}</span>
                {d.ok ? (
                  <span className={[styles.result, styles.ok].join(' ')}>
                    <CheckCircleIcon size={18} />
                    in Ordnung
                  </span>
                ) : (
                  <span className={[styles.result, styles.notOk].join(' ')}>
                    <AlertIcon size={18} />
                    nicht in Ordnung
                  </span>
                )}
              </span>
              {d.text && <span className={styles.deviceText}>{d.text}</span>}
            </li>
          ))}
        </ul>
        {report.deviceModel && <p className={styles.model}>Gerät: {report.deviceModel}</p>}
      </div>
    );
  }

  // Eine Form, die die Seite nicht kennt: der Inhalt, wie er ist.
  return (
    <div className={styles.content}>
      <CodeBlock title="Inhalt" copyLabel="Inhalt kopieren" text={JSON.stringify(report.content, null, 2)} />
    </div>
  );
}
