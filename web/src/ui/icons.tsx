import type { ReactNode, SVGProps } from 'react';

/**
 * Symbole als eingebettetes SVG im Stil der App (24er Raster, Linie 2, runde Enden, wie Lucide).
 * Sie sind Beiwerk: jeder Knopf mit Symbol hat daneben eine Beschriftung.
 */
type IconProps = Omit<SVGProps<SVGSVGElement>, 'children'> & { size?: number };

function icon(paths: ReactNode, strokeWidth = 2) {
  return function Icon({ size = 20, ...rest }: IconProps) {
    return (
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
        focusable="false"
        {...rest}
      >
        {paths}
      </svg>
    );
  };
}

/** Beleg mit zwei Zeilen: das Logo von Kassa. */
export const ReceiptIcon = icon(
  <>
    <path d="M6 3h12v18l-3-2-3 2-3-2-3 2z" />
    <path d="M9.5 8h5M9.5 12h5" />
  </>,
  2.4,
);

/** Laden mit Markise: Betriebe. */
export const StoreIcon = icon(
  <>
    <path d="M3 9.5 4.6 4h14.8L21 9.5" />
    <path d="M3 9.5a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0" />
    <path d="M5 12v8h14v-8" />
    <path d="M10 20v-4.5h4V20" />
  </>,
);

export const LogOutIcon = icon(
  <>
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <path d="m16 17 5-5-5-5" />
    <path d="M21 12H9" />
  </>,
);

export const AlertIcon = icon(
  <>
    <circle cx="12" cy="12" r="10" />
    <path d="M12 8v4" />
    <path d="M12 16h.01" />
  </>,
);

export const CloseIcon = icon(
  <>
    <path d="M18 6 6 18" />
    <path d="m6 6 12 12" />
  </>,
);

/** Kette mit Lücke: ein Link, der nicht mehr gilt. */
export const LinkOffIcon = icon(
  <>
    <path d="M9 17H7A5 5 0 0 1 7 7" />
    <path d="M15 7h2a5 5 0 0 1 4 8" />
    <path d="M8 12h4" />
    <path d="m2 2 20 20" />
  </>,
);

export const PlusIcon = icon(
  <>
    <path d="M5 12h14" />
    <path d="M12 5v14" />
  </>,
);

export const UploadIcon = icon(
  <>
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <path d="m17 8-5-5-5 5" />
    <path d="M12 3v12" />
  </>,
);

/** Pfeil in eine Schale: Installationsdateien. */
export const DownloadIcon = icon(
  <>
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <path d="m7 10 5 5 5-5" />
    <path d="M12 15V3" />
  </>,
);

export const CheckCircleIcon = icon(
  <>
    <circle cx="12" cy="12" r="10" />
    <path d="m9 12 2 2 4-4" />
  </>,
);

/** Kreis mit Strich: gesperrt. */
export const BanIcon = icon(
  <>
    <circle cx="12" cy="12" r="10" />
    <path d="m4.9 4.9 14.2 14.2" />
  </>,
);

export const ChevronRightIcon = icon(<path d="m9 18 6-6-6-6" />);

/** Tablet: Kassen. */
export const TabletIcon = icon(
  <>
    <rect width="16" height="20" x="4" y="2" rx="2" />
    <path d="M12 18h.01" />
  </>,
);

export const UsersIcon = icon(
  <>
    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
    <circle cx="9" cy="7" r="4" />
    <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
  </>,
);

/** Aufgeschlagenes Buch: Speisekarte. */
export const BookIcon = icon(
  <>
    <path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z" />
    <path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z" />
  </>,
);

/** Säulen auf einer Achse: Umsätze. */
export const ChartIcon = icon(
  <>
    <path d="M3 3v16a2 2 0 0 0 2 2h16" />
    <path d="M18 17V9" />
    <path d="M13 17V5" />
    <path d="M8 17v-3" />
  </>,
);

export const ArrowUpIcon = icon(
  <>
    <path d="m5 12 7-7 7 7" />
    <path d="M12 19V5" />
  </>,
);

export const ArrowDownIcon = icon(
  <>
    <path d="M12 5v14" />
    <path d="m19 12-7 7-7-7" />
  </>,
);

export const ChevronLeftIcon = icon(<path d="m15 18-6-6 6-6" />);

/** Beleg mit Zeilen, in der Strichstärke der anderen Bereiche: Bons. */
export const ReceiptLinesIcon = icon(
  <>
    <path d="M5 3h14v18l-2.5-1.5L14 21l-2-1.5-2 1.5-2.5-1.5L5 21z" />
    <path d="M9 8h6M9 12h6M9 16h3" />
  </>,
);

/** Kalender mit Haken: Abschlüsse. */
export const CalendarCheckIcon = icon(
  <>
    <rect width="18" height="18" x="3" y="4" rx="2" />
    <path d="M16 2v4M8 2v4M3 10h18" />
    <path d="m9 16 2 2 4-4" />
  </>,
);

/** Drucker: ein Blatt drucken. */
export const PrinterIcon = icon(
  <>
    <path d="M7 9V4h10v5" />
    <rect x="4" y="9" width="16" height="8" rx="2" />
    <path d="M7 14h10v6H7z" />
  </>,
);

/** Vier Kacheln: weitere Bereiche ("Mehr"). */
export const GridIcon = icon(
  <>
    <rect width="7" height="7" x="3" y="3" rx="1.5" />
    <rect width="7" height="7" x="14" y="3" rx="1.5" />
    <rect width="7" height="7" x="3" y="14" rx="1.5" />
    <rect width="7" height="7" x="14" y="14" rx="1.5" />
  </>,
);

/** Stern: Favorit (gefüllt, wenn an). */
export const StarIcon = icon(
  <path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z" />,
);

/** Kamera: Foto-Feld ohne Foto. */
export const CameraIcon = icon(
  <>
    <path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z" />
    <circle cx="12" cy="13" r="3" />
  </>,
);

/** Regler: der Bereich "Betrieb" (Einstellungen des Betriebs). */
export const SlidersIcon = icon(
  <>
    <path d="M21 4h-7M10 4H3M21 12h-9M8 12H3M21 20h-5M12 20H3" />
    <path d="M14 2v4M8 10v4M16 18v4" />
  </>,
);

/** Käfer: Fehlerberichte. */
export const BugIcon = icon(
  <>
    <path d="m8 2 1.88 1.88" />
    <path d="M14.12 3.88 16 2" />
    <path d="M9 7.13v-1a3.003 3.003 0 1 1 6 0v1" />
    <path d="M12 20c-3.3 0-6-2.7-6-6v-3a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v3c0 3.3-2.7 6-6 6" />
    <path d="M12 20v-9" />
    <path d="M6.53 9C4.6 8.8 3 7.1 3 5" />
    <path d="M6 13H2" />
    <path d="M3 21c0-2.1 1.7-3.9 3.8-4" />
    <path d="M20.97 5c0 2.1-1.6 3.8-3.5 4" />
    <path d="M22 13h-4" />
    <path d="M17.2 17c2.1.1 3.8 1.9 3.8 4" />
  </>,
);

/** Zwei Blätter: kopieren. */
export const CopyIcon = icon(
  <>
    <rect width="14" height="14" x="8" y="8" rx="2" ry="2" />
    <path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" />
  </>,
);

export const ChevronDownIcon = icon(<path d="m6 9 6 6 6-6" />);
