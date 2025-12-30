import { test, expect } from '@playwright/test';
import fs from 'fs';
import zlib from 'zlib';

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let k = 0; k < 8; k += 1) {
      c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    }
    table[i] = c >>> 0;
  }
  return table;
})();

const crc32 = (buf: Buffer): number => {
  let c = 0xffffffff;
  for (const b of buf) {
    c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
};

const pngChunk = (type: string, data: Buffer): Buffer => {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([length, typeBuf, data, crc]);
};

const makeSolidPng = (width: number, height: number, rgba: [number, number, number, number]): Buffer => {
  const [r, g, b, a] = rgba;
  const rowSize = width * 4 + 1;
  const raw = Buffer.alloc(rowSize * height);
  for (let y = 0; y < height; y += 1) {
    const rowOffset = y * rowSize;
    raw[rowOffset] = 0;
    for (let x = 0; x < width; x += 1) {
      const pixelOffset = rowOffset + 1 + x * 4;
      raw[pixelOffset] = r;
      raw[pixelOffset + 1] = g;
      raw[pixelOffset + 2] = b;
      raw[pixelOffset + 3] = a;
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const idat = zlib.deflateSync(raw);
  return Buffer.concat([
    PNG_SIGNATURE,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', idat),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
};

test('upload image and show gallery', async ({ page }, testInfo) => {
  await page.goto('/');

  await page.getByRole('button', { name: '画像', exact: true }).click();

  const filePath = testInfo.outputPath('upload.png');
  fs.writeFileSync(filePath, makeSolidPng(16, 16, [255, 0, 0, 255]));

  await page.locator('input[type="file"]').first().setInputFiles(filePath);
  await page.getByRole('button', { name: /アップロード/ }).click();

  await expect(page.getByText(/成功:\s*1/)).toBeVisible({ timeout: 120000 });

  await page.getByRole('button', { name: '画像一覧' }).click();
  await page.getByRole('button', { name: '更新' }).click();

  await expect(page.getByText('画像を読み込み中...')).toBeHidden({ timeout: 120000 });
  await expect
    .poll(async () => {
      await page.getByRole('button', { name: '更新' }).click();
      return page.locator('img[loading="lazy"]').count();
    }, { timeout: 120000 })
    .toBeGreaterThan(0);
});
