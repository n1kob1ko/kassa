import { fileUrl } from '../api/files';
import type { ItemChange, MenuItem } from '../api/items';
import { money } from '../format';
import { StarIcon } from '../ui/icons';
import { Photo, PhotoButton } from '../ui/PhotoButton';
import { PriceField } from '../ui/PriceField';
import { StatusChip } from '../ui/StatusChip';
import { Switch } from '../ui/Switch';
import styles from './MenuPage.module.css';

export type MenuItemRowProps = {
  business: string;
  item: MenuItem;
  onChange: (change: ItemChange) => void;
  onPhoto: () => void;
};

/**
 * Eine Zeile der Speisekarte: Foto-Feld, Name, Preis, "Im Verkauf", Favorit. Am Handy zwei Zeilen (Foto, Name und
 * Stern oben, Preis und Schalter darunter), ab 640 px eine Zeile unter den Spaltenköpfen der Kategorie.
 * Die Namen für Screenreader nennen den Artikel: "Huhn Bowl: Preis", "Huhn Bowl: im Verkauf", "Huhn Bowl: Favorit".
 */
export function MenuItemRow({ business, item, onChange, onPhoto }: MenuItemRowProps) {
  return (
    <li className={styles.row}>
      <PhotoButton
        className={styles.photo}
        picture={item.photo}
        src={(id) => fileUrl(business, id)}
        label={`${item.name}: Foto ${item.photo ? 'ändern' : 'hinzufügen'}`}
        onClick={onPhoto}
      />
      <p className={styles.name}>{item.name}</p>
      <PriceField
        className={styles.price}
        errorClassName={styles.priceError}
        label={`${item.name}: Preis`}
        cents={item.priceCents}
        onCommit={(priceCents) => onChange({ priceCents })}
      />
      <Switch
        className={styles.sale}
        labelClassName={styles.saleLabel}
        label="Im Verkauf"
        name={`${item.name}: im Verkauf`}
        checked={item.inSale}
        onChange={(inSale) => onChange({ inSale })}
      />
      <button
        type="button"
        className={styles.star}
        aria-label={`${item.name}: Favorit`}
        aria-pressed={item.favorite}
        onClick={() => onChange({ favorite: !item.favorite })}
      >
        <StarIcon size={22} className={styles.starIcon} />
      </button>
    </li>
  );
}

/** Ein stillgelegter Artikel: nur zum Lesen, gedämpft, mit dem Zeichen "Stillgelegt" (in einer stillgelegten Kategorie steht es an der Kategorie). */
export function ArchivedItemRow({ business, item, chip }: { business: string; item: MenuItem; chip: boolean }) {
  return (
    <li className={[styles.row, styles.archivedRow].join(' ')}>
      <Photo className={styles.photo} picture={item.photo} src={(id) => fileUrl(business, id)} />
      <p className={styles.name}>
        <span>{item.name}</span>
        {chip && <StatusChip tone="neutral">Stillgelegt</StatusChip>}
      </p>
      <span className={styles.archivedPrice}>{money(item.priceCents)}</span>
    </li>
  );
}
