import { useId, useState, type CSSProperties, type ReactNode } from 'react';
import {
  useImportTranslations,
  useSetTranslation,
  useTranslations,
  type TranslationLang,
  type TranslationRow,
  type TranslationSection,
} from '../api/translations';
import { count, keepUnits } from '../format';
import { Button } from '../ui/Button';
import { LoadError } from '../ui/DataList';
import { Dialog } from '../ui/Dialog';
import { EmptyState } from '../ui/EmptyState';
import { FileDrop, UploadError } from '../ui/FileDrop';
import { UploadIcon } from '../ui/icons';
import { PageHeader } from '../ui/PageHeader';
import { Segmented } from '../ui/Segmented';
import { Bone } from '../ui/Skeleton';
import { StatusChip } from '../ui/StatusChip';
import { Switch } from '../ui/Switch';
import { TextField } from '../ui/TextField';
import { toast } from '../ui/Toast';
import { useDialogState } from '../ui/useDialogState';
import { BusinessName, useBusinessContext } from './BusinessLayout';
import { LANGUAGES, languageOf, progressOf, progressText, storedLanguage, visibleSections, type Language } from './translations';
import { useSyncHint } from './useSyncHint';
import styles from './TranslationsPage.module.css';

const LANGUAGE_STORAGE = 'kassa.uebersetzungen.sprache';

/** Die zuletzt gewählte Sprache dieses Browsers; ohne Speicher (privates Fenster) gilt English. */
function useLanguage(): [TranslationLang, (lang: TranslationLang) => void] {
  const [lang, setLang] = useState<TranslationLang>(() => {
    try {
      return storedLanguage(localStorage.getItem(LANGUAGE_STORAGE));
    } catch {
      return 'en';
    }
  });
  const choose = (next: TranslationLang) => {
    setLang(next);
    try {
      localStorage.setItem(LANGUAGE_STORAGE, next);
    } catch {
      // Ohne Speicher gilt die Wahl nur bis zum Neuladen.
    }
  };
  return [lang, choose];
}

function ImportDialog({ business, open, onClose }: { business: string; open: boolean; onClose: () => void }) {
  const importFile = useImportTranslations(business);
  const [file, setFile] = useState<File>();

  const submit = async () => {
    if (!file || importFile.isPending) return;
    importFile.mutate(await file.text(), {
      onSuccess: ({ changed }) => {
        onClose();
        toast.show(`${count(changed, 'Name', 'Namen')} übersetzt.`);
      },
    });
  };

  return (
    <Dialog
      title="Übersetzungen einspielen"
      open={open}
      onClose={onClose}
      actions={
        <>
          <Button variant="quiet" onClick={onClose}>
            Abbrechen
          </Button>
          <Button variant="primary" busy={importFile.isPending} disabled={!file} onClick={() => void submit()}>
            Einspielen
          </Button>
        </>
      }
    >
      <div className={styles.dialogBody}>
        <p>Die Datei enthält nur "uebersetzungen". Sie gewinnt bei jedem Namen, der in ihr steht; Artikel und Preise bleiben, wie sie sind.</p>
        <FileDrop
          kind="translations"
          onFile={(f) => {
            importFile.reset();
            setFile(f);
          }}
          fileName={file?.name}
          disabled={importFile.isPending}
        />
        {importFile.error && <UploadError error={importFile.error} />}
      </div>
    </Dialog>
  );
}

type TranslationFieldProps = {
  row: TranslationRow;
  language: Language;
  onCommit: (value: string) => void;
};

/**
 * Das Feld einer Übersetzung. Verlassen und Enter speichern, aber nur einen anderen Text; Escape stellt den
 * gespeicherten wieder her. Ein Text gleich dem Namen ist eine Übersetzung; leer heißt: der Name gilt.
 */
function TranslationField({ row, language, onCommit }: TranslationFieldProps) {
  const value = row.values[language.code] ?? '';
  const [draft, setDraft] = useState(value);
  const [seen, setSeen] = useState(value);
  const [editing, setEditing] = useState(false);
  // Kommt ein anderer Wert (vom Server gekürzt, oder nach einem Fehler zurück), steht er da, solange niemand tippt.
  if (value !== seen) {
    setSeen(value);
    if (!editing) setDraft(value);
  }

  const commit = () => {
    setEditing(false);
    const next = draft.trim();
    setDraft(next);
    if (next !== value) onCommit(next);
  };

  const label = `${row.source}: ${language.name}`;
  return (
    <TextField
      className={styles.field}
      label={label}
      hideLabel
      aria-label={label}
      lang={language.tag}
      dir={language.dir}
      // Im Feld von rechts nach links bleibt der deutsche Name als Platzhalter für sich links nach rechts ("5 Stück").
      placeholder={language.dir === 'rtl' ? `\u2066${row.source}\u2069` : row.source}
      autoComplete="off"
      enterKeyHint="done"
      maxLength={200}
      value={draft}
      onChange={(e) => {
        setEditing(true);
        setDraft(e.currentTarget.value);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          commit();
        } else if (e.key === 'Escape') {
          e.preventDefault();
          e.stopPropagation();
          setEditing(false);
          setDraft(value);
        }
      }}
      onBlur={commit}
    />
  );
}

function SectionGroup({ section, language, children }: { section: TranslationSection; language: Language; children: ReactNode }) {
  const headingId = useId();
  return (
    <section className={styles.group} aria-labelledby={headingId}>
      <div className={styles.groupHead}>
        <h2 id={headingId} className={styles.heading}>
          {section.title}
        </h2>
        {/* Ab 640 px über der Spalte der Felder; die Felder tragen die Sprache in ihrem Namen, darum nur zum Sehen. */}
        <span className={styles.columnLang} lang={language.tag} dir={language.dir} aria-hidden="true">
          {language.name}
        </span>
      </div>
      <ul className={styles.card} aria-label={section.title}>
        {children}
      </ul>
    </section>
  );
}

/** Stand der gewählten Sprache: Balken, der weich mitwächst, und Text mit gleich breiten Ziffern. Ohne Zahlen (beim Laden) schimmert er. */
function Progress({ progress }: { progress?: { done: number; total: number } }) {
  if (!progress) {
    return (
      <p className={styles.progress} aria-hidden="true">
        <Bone className={styles.boneBar} />
        <Bone className={styles.boneProgress} />
      </p>
    );
  }
  const { done, total } = progress;
  return (
    <p className={styles.progress} data-testid="translation-progress">
      <span className={styles.bar} aria-hidden="true">
        <span className={styles.barFill} style={{ '--share': total > 0 ? done / total : 0 } as CSSProperties} />
      </span>
      <span className={styles.progressText}>{progressText(done, total)}</span>
    </p>
  );
}

/** Platzhalter in der Form der Tabelle: Überschrift, Zeilen mit Name und Feld. */
function TranslationsSkeleton() {
  return (
    <div className={styles.groups} role="status" aria-busy="true">
      <span className="visually-hidden">Übersetzungen werden geladen</span>
      {[2, 4].map((rows, g) => (
        <div key={g} className={styles.group} aria-hidden="true">
          <div className={styles.groupHead}>
            <Bone className={styles.boneHeading} />
          </div>
          <div className={styles.card}>
            {Array.from({ length: rows }, (_, i) => (
              <div key={i} className={styles.row}>
                <span className={styles.name}>
                  <Bone className={styles.boneName} />
                </span>
                <Bone className={[styles.field, styles.boneField].join(' ')} />
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

export function TranslationsPage() {
  const { detail, isProvider } = useBusinessContext();
  const b = detail.business.id;
  const translations = useTranslations(b);
  const hint = useSyncHint();
  const save = useSetTranslation(b, { onSaved: () => hint() });
  const importDialog = useDialogState();
  const [lang, setLang] = useLanguage();
  const [onlyMissing, setOnlyMissing] = useState(false);
  // Unter "Nur fehlende" eben übersetzte Namen: sie bleiben stehen, bis Filter oder Sprache wechseln.
  const [keep, setKeep] = useState<ReadonlySet<string>>(new Set());
  const language = languageOf(lang);

  const chooseLanguage = (next: TranslationLang) => {
    setLang(next);
    setKeep(new Set());
  };
  const chooseOnlyMissing = (on: boolean) => {
    setOnlyMissing(on);
    setKeep(new Set());
  };
  const commit = (row: TranslationRow, value: string) => {
    if (onlyMissing) setKeep((k) => new Set(k).add(row.source));
    save.mutate({ source: row.source, lang, value });
  };

  let content: ReactNode;
  let progress: { done: number; total: number } | undefined;
  if (translations.isPending) {
    content = <TranslationsSkeleton />;
  } else if (translations.isLoadingError) {
    content = <LoadError message={translations.error.message} onRetry={() => void translations.refetch()} />;
  } else {
    const { sections } = translations.data;
    progress = progressOf(sections, lang);
    if (progress.total === 0) {
      content = (
        <EmptyState
          title="Noch keine Speisekarte."
          text={
            isProvider
              ? 'Spiel die Speisekarte ein, dann stehen ihre Namen hier zum Übersetzen.'
              : 'Sobald dein Anbieter die Speisekarte einspielt, stehen ihre Namen hier zum Übersetzen.'
          }
        />
      );
    } else {
      const shown = visibleSections(sections, lang, onlyMissing, keep);
      content =
        shown.length === 0 ? (
          <EmptyState title="Nichts fehlt." text={`Jeder Name hat eine Übersetzung in ${language.name}.`} />
        ) : (
          <div className={styles.groups}>
            {shown.map((section) => (
              <SectionGroup key={`${section.kind}/${section.title}`} section={section} language={language}>
                {section.rows.map((row) => {
                  const missing = (row.values[lang] ?? '') === '';
                  return (
                    <li key={row.source} className={styles.row}>
                      <p className={styles.name}>
                        <span className={styles.nameText}>{keepUnits(row.source)}</span>
                        {missing && <StatusChip tone="neutral">fehlt</StatusChip>}
                      </p>
                      <TranslationField key={lang} row={row} language={language} onCommit={(value) => commit(row, value)} />
                    </li>
                  );
                })}
              </SectionGroup>
            ))}
          </div>
        );
    }
  }

  return (
    <>
      <PageHeader
        title="Übersetzungen"
        subtitle={<BusinessName />}
        actions={
          isProvider ? (
            <Button variant="secondary" onClick={() => importDialog.show()}>
              <UploadIcon size={18} />
              Übersetzungen einspielen
            </Button>
          ) : undefined
        }
      />
      {/* Sprache, Stand und Filter stehen schon beim Laden da: nichts springt, wenn die Namen kommen. */}
      {(translations.isPending || (progress && progress.total > 0)) && (
        <div className={styles.toolbar}>
          <Segmented
            className={styles.languages}
            label="Sprache"
            options={LANGUAGES.map((l) => ({ value: l.code, label: l.name }))}
            value={lang}
            onChange={chooseLanguage}
          />
          <div className={styles.status}>
            <Progress progress={progress} />
            <Switch label="Nur fehlende" checked={onlyMissing} onChange={chooseOnlyMissing} />
          </div>
        </div>
      )}
      {content}
      {isProvider && <ImportDialog key={importDialog.key} business={b} open={importDialog.open} onClose={importDialog.close} />}
    </>
  );
}
