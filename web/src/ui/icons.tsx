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
