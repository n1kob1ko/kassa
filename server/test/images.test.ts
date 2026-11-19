import { readFileSync } from 'node:fs';
import sharp from 'sharp';
import { describe, expect, test } from 'vitest';
import { ApiError } from '../src/errors.js';
import { processImage } from '../src/files/images.js';

const image = (name: string) => readFileSync(new URL(`./fixtures/images/${name}`, import.meta.url));

const rejects = async (input: Buffer) => {
  const err = await processImage(input).then(
    () => undefined,
    (e: unknown) => e,
  );
  expect(err).toBeInstanceOf(ApiError);
  expect(err).toMatchObject({
    status: 422,
    code: 'image_invalid',
    message: 'Das ist kein Bild, das Kassa lesen kann. Nimm JPEG, PNG oder WebP.',
  });
};

describe('processImage', () => {
  test('ein JPEG mit 1600 Pixel Breite wird ein WebP mit 800 Pixel Breite', async () => {
    const jpeg = await sharp({ create: { width: 1600, height: 1200, channels: 3, background: '#336699' } }).jpeg().toBuffer();
    const out = await processImage(jpeg);
    const meta = await sharp(out.data).metadata();
    expect(meta.format).toBe('webp');
    expect([meta.width, meta.height]).toEqual([800, 600]);
    expect([out.width, out.height]).toEqual([800, 600]);
  });

  test('ein Bild mit 400 Pixel Breite bleibt bei 400 (nie vergrößert)', async () => {
    const out = await processImage(image('plain_400.jpg'));
    expect([out.width, out.height]).toEqual([400, 300]);
    expect((await sharp(out.data).metadata()).width).toBe(400);
  });

  test('ein gedrehtes JPEG kommt aufrecht heraus: Breite und Höhe sind getauscht, die Ausrichtung ist weg', async () => {
    const input = image('rotated_gps.jpg');
    const before = await sharp(input).metadata();
    expect([before.width, before.height, before.orientation]).toEqual([1600, 1000, 6]);
    const out = await processImage(input);
    // 1000 x 1600 aufrecht, davon auf 800 Breite verkleinert.
    expect([out.width, out.height]).toEqual([800, 1280]);
    const after = await sharp(out.data).metadata();
    expect([after.width, after.height]).toEqual([800, 1280]);
    expect(after.orientation === undefined || after.orientation === 1).toBe(true);
  });

  test('die Ausgabe enthält keine Metadaten (weder EXIF noch Ortsangabe)', async () => {
    const input = image('rotated_gps.jpg');
    expect((await sharp(input).metadata()).exif).toBeDefined();
    const out = await processImage(input);
    const meta = await sharp(out.data).metadata();
    expect(meta.exif).toBeUndefined();
    expect(meta.icc).toBeUndefined();
    expect(meta.xmp).toBeUndefined();
    expect(out.data.includes(Buffer.from('Exif'))).toBe(false);
    expect(out.data.includes(Buffer.from('EXIF'))).toBe(false);
  });

  test('ein PNG behält den durchsichtigen Hintergrund', async () => {
    const out = await processImage(image('transparent.png'));
    const meta = await sharp(out.data).metadata();
    expect(meta.hasAlpha).toBe(true);
    const { data, info } = await sharp(out.data).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    expect(data[3]).toBe(0); // linke obere Ecke: durchsichtig
    const mid = ((info.height / 2) * info.width + info.width / 2) * 4;
    expect(data[mid + 3]).toBe(255); // Mitte: das rote Quadrat
  });

  test('ein WebP wird angenommen', async () => {
    const out = await processImage(image('photo.webp'));
    expect([out.width, out.height]).toEqual([300, 200]);
  });

  test('color ist die mittlere Farbe als #rrggbb', async () => {
    const out = await processImage(image('plain_400.jpg'));
    expect(out.color).toMatch(/^#[0-9a-f]{6}$/);
    // Der Hintergrund war #40a060, JPEG und WebP verschieben es nur leicht.
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(out.color.slice(i, i + 2), 16));
    expect(Math.abs(r! - 0x40)).toBeLessThan(12);
    expect(Math.abs(g! - 0xa0)).toBeLessThan(12);
    expect(Math.abs(b! - 0x60)).toBeLessThan(12);
  });

  test('color passt auch bei durchsichtigem Bild', async () => {
    expect((await processImage(image('transparent.png'))).color).toMatch(/^#[0-9a-f]{6}$/);
  });

  test('eine Textdatei mit Endung .jpg ist kein Bild', async () => {
    await rejects(image('not_an_image.jpg'));
  });

  test('eine leere Datei ist kein Bild', async () => {
    await rejects(Buffer.alloc(0));
  });

  test('ein abgeschnittenes JPEG ist kein Bild', async () => {
    const whole = image('rotated_gps.jpg');
    await rejects(whole.subarray(0, Math.floor(whole.length / 2)));
  });

  test('ein Bild über 50 Millionen Pixel wird abgelehnt', async () => {
    // 8000 x 7000 = 56 Millionen Pixel, einfarbig und deshalb klein.
    const big = await sharp({ create: { width: 8000, height: 7000, channels: 3, background: '#ffffff' } }).png({ compressionLevel: 9 }).toBuffer();
    await rejects(big);
  });
});
