import type { ReactNode } from 'react';
import { useRemoveLogo, useSetLogo } from '../api/businesses';
import { fileUrl, type UploadOptions } from '../api/files';
import { Button } from '../ui/Button';
import { Card } from '../ui/Card';
import { PageHeader } from '../ui/PageHeader';
import { PhotoButton } from '../ui/PhotoButton';
import { useDialogState } from '../ui/useDialogState';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { PhotoDialog } from './PhotoDialog';
import { removeWithUndo, useSyncHint, useUploadMemory } from './useSyncHint';
import styles from './BusinessPage.module.css';

const PROVIDER_NOTE = 'Ändern kommt mit der nächsten Stufe. Bis dahin: Speisekarte neu einspielen.';
const LOGO_KEY = 'logo';
const LOGO_BUTTON = 'betrieb-logo-knopf';

/** Eine Angabe zum Lesen; fehlt sie, steht das ruhig da. */
function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className={styles.fact}>
      <dt className={styles.factLabel}>{label}</dt>
      <dd className={styles.factValue}>{children ?? <span className={styles.missing}>Nicht angegeben</span>}</dd>
    </div>
  );
}

/** Seite "Betrieb": das Logo (hochladen, ersetzen, entfernen) und die Angaben des Betriebs zum Lesen. */
export function BusinessPage() {
  const { detail, isProvider } = useBusinessContext();
  const { business } = detail;
  const setLogo = useSetLogo(business.id);
  const removeLogo = useRemoveLogo(business.id);
  const dialog = useDialogState();
  const hint = useSyncHint();
  const memory = useUploadMemory();
  const logo = business.logo;
  const logoFile = memory.fileOf(LOGO_KEY, logo?.id);
  const src = (id: string) => fileUrl(business.id, id);

  const upload = async (file: File, options: UploadOptions) => {
    const saved = await setLogo.mutateAsync({ file, ...options });
    memory.remember(LOGO_KEY, saved.id, file);
  };

  const address = business.addressLines.filter((l) => l.trim() !== '');

  return (
    <>
      <PageHeader title="Betrieb" subtitle={<BusinessName />} />

      <div className={styles.layout}>
        <Card className={styles.card} aria-labelledby="betrieb-logo">
          <h2 id="betrieb-logo" className={styles.cardTitle}>
            Logo
          </h2>
          <div className={styles.logoRow}>
            {/* Die große Fläche ist zum Antippen da; Tastatur und Screenreader nehmen den Knopf daneben. */}
            <PhotoButton
              decorative
              size="lg"
              fit="contain"
              picture={logo}
              src={src}
              label={logo ? 'Logo ändern' : 'Logo hinzufügen'}
              onClick={() => dialog.show()}
            />
            <div className={styles.logoText}>
              <p>{logo ? 'Steht neben dem Namen des Betriebs.' : 'Noch kein Logo. Es steht dann neben dem Namen des Betriebs.'}</p>
              <p className={styles.logoHint}>JPEG, PNG oder WebP, bis 10 MB.</p>
              <Button id={LOGO_BUTTON} variant="secondary" onClick={() => dialog.show()} aria-haspopup="dialog">
                {logo ? 'Logo ändern' : 'Logo hinzufügen'}
              </Button>
            </div>
          </div>
        </Card>

        <Card className={styles.card} aria-labelledby="betrieb-angaben">
          <h2 id="betrieb-angaben" className={styles.cardTitle}>
            Angaben
          </h2>
          {isProvider && <p className={styles.note}>{PROVIDER_NOTE}</p>}
          <dl className={styles.facts}>
            <Fact label="Name">{business.name}</Fact>
            <Fact label="Adresse">
              {address.length > 0
                ? address.map((line, i) => (
                    <span key={i} className={styles.line}>
                      {line}
                    </span>
                  ))
                : null}
            </Fact>
            <Fact label="UID">{business.vatId}</Fact>
            <Fact label="Text am Bon-Ende">{business.receiptFooter}</Fact>
          </dl>
        </Card>
      </div>

      <PhotoDialog
        key={dialog.key}
        open={dialog.open}
        onClose={dialog.close}
        title="Logo"
        noun="Logo"
        fit="contain"
        current={logo}
        src={src}
        onSave={async (file, options) => {
          await upload(file, options);
          hint();
        }}
        undoable={logoFile !== undefined}
        // Die große Fläche ist nicht in der Tab-Reihe: der Fokus kommt zum beschrifteten Knopf zurück.
        returnFocus={() => document.getElementById(LOGO_BUTTON)}
        onRemove={async () => {
          if (logoFile) {
            removeWithUndo({
              remove: () => removeLogo.mutateAsync(),
              reupload: () => upload(logoFile, {}),
              message: 'Logo entfernt.',
              notify: hint,
            });
            return;
          }
          await removeLogo.mutateAsync();
          hint('Logo entfernt.');
        }}
      />
    </>
  );
}
