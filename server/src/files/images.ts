import sharp from 'sharp';
import { ApiError } from '../errors.js';

export const MAX_IMAGE_WIDTH = 800;
/** Größere Eingaben könnten beim Entpacken den Speicher füllen. */
export const MAX_INPUT_PIXELS = 50_000_000;

const invalid = () =>
  new ApiError(422, 'image_invalid', 'Das ist kein Bild, das Kassa lesen kann. Nimm JPEG, PNG oder WebP.');

export type ProcessedImage = { data: Buffer; width: number; height: number; color: string };

const hex = (n: number) => Math.min(255, Math.max(0, Math.round(n))).toString(16).padStart(2, '0');

/**
 * Macht aus dem, was hochgeladen wurde, ein kleines WebP: nach EXIF aufgerichtet, höchstens 800 Pixel breit,
 * nie vergrößert, ohne Metadaten (auch ohne Ortsangabe). Was die Bytes wirklich sind, entscheidet allein sharp.
 * Alles, was sich nicht lesen lässt (Text, leer, abgeschnitten, zu groß), ist `image_invalid`.
 */
export async function processImage(input: Buffer): Promise<ProcessedImage> {
  try {
    const { data, info } = await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: 'truncated' })
      .rotate()
      .resize({ width: MAX_IMAGE_WIDTH, withoutEnlargement: true })
      .webp({ quality: 80 })
      .toBuffer({ resolveWithObject: true });
    // Mittlere Farbe; durchsichtige Stellen zählen als weiß.
    const stats = await sharp(data).flatten({ background: '#ffffff' }).stats();
    const [r, g, b] = stats.channels.map((c) => c.mean);
    return { data, width: info.width, height: info.height, color: `#${hex(r!)}${hex(g!)}${hex(b!)}` };
  } catch {
    throw invalid();
  }
}
