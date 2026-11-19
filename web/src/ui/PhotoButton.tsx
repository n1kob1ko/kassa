import type { CSSProperties, Ref } from 'react';
import type { Picture } from '../api/files';
import { CameraIcon } from './icons';
import styles from './PhotoButton.module.css';

export type PhotoProps = {
  picture: Picture | null;
  /** Adresse des Bilds zur Kennung. */
  src: (id: string) => string;
  /** `cover` für Fotos (füllt die Fläche), `contain` für ein Logo (ganz zu sehen). */
  fit?: 'cover' | 'contain';
  className?: string;
};

/**
 * Das Bild in seiner Fläche. Solange es lädt, steht seine Hauptfarbe da; ein neues Bild hat eine neue Kennung und
 * damit eine neue Adresse, es blendet über der Farbe ein, nie über dem alten Bild. Ohne Bild: ein Kamera-Zeichen.
 */
export function Photo({ picture, src, fit = 'cover', className }: PhotoProps) {
  return (
    <span
      className={[styles.frame, picture ? '' : styles.empty, className].filter(Boolean).join(' ')}
      // Die Farbe kommt vom Server und steht als Variable am Element (CSSOM, kein Stil im HTML).
      style={picture ? ({ '--placeholder': picture.color } as CSSProperties) : undefined}
    >
      {picture ? (
        <img
          key={picture.id}
          className={[styles.image, fit === 'contain' ? styles.contain : ''].filter(Boolean).join(' ')}
          src={src(picture.id)}
          alt=""
          decoding="async"
          draggable={false}
          onLoad={(e) => {
            e.currentTarget.dataset.loaded = 'true';
          }}
        />
      ) : (
        <CameraIcon size={22} className={styles.camera} />
      )}
    </span>
  );
}

export type PhotoButtonProps = PhotoProps & {
  /** Name für Screenreader, etwa "Huhn Bowl: Foto ändern". */
  label: string;
  onClick: () => void;
  /** `md` 56 px (Zeile der Speisekarte), `lg` 96 px (Logo). */
  size?: 'md' | 'lg';
  /** Nur für Maus und Finger, wenn daneben ein beschrifteter Knopf dasselbe tut: nicht in der Tab-Reihe, nicht vorgelesen. */
  decorative?: boolean;
  ref?: Ref<HTMLButtonElement>;
};

/** Das Foto-Feld: ein Knopf in der Größe des Bilds, der das Fenster zum Wählen öffnet. */
export function PhotoButton({ label, onClick, size = 'md', decorative = false, ref, className, ...photo }: PhotoButtonProps) {
  return (
    <button
      ref={ref}
      type="button"
      className={[styles.button, size === 'lg' ? styles.lg : '', className].filter(Boolean).join(' ')}
      aria-label={decorative ? undefined : label}
      aria-haspopup={decorative ? undefined : 'dialog'}
      aria-hidden={decorative || undefined}
      tabIndex={decorative ? -1 : undefined}
      onClick={onClick}
    >
      <Photo {...photo} className={styles.fill} />
    </button>
  );
}
