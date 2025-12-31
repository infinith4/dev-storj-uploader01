import { StorjImageItem } from '../types';

const VIDEO_EXTENSIONS = new Set([
  '.mp4',
  '.mov',
  '.avi',
  '.mkv',
  '.webm',
  '.m4v',
  '.3gp',
  '.flv',
  '.wmv',
]);

const looksLikeVideoThumbnail = (value: string | null | undefined): boolean => {
  if (!value) return false;
  return value.toLowerCase().includes('_thumb');
};

export const isVideoPath = (path: string | null | undefined): boolean => {
  if (!path) return false;
  const normalized = path.split('?')[0].toLowerCase();
  const dotIndex = normalized.lastIndexOf('.');
  if (dotIndex === -1) return false;
  return VIDEO_EXTENSIONS.has(normalized.slice(dotIndex));
};

export const resolveIsVideo = (item: StorjImageItem): boolean => {
  const isVideoValue: unknown = item.is_video;
  if (typeof isVideoValue === 'boolean') {
    return isVideoValue;
  }
  if (typeof isVideoValue === 'number') {
    return isVideoValue !== 0;
  }
  if (typeof isVideoValue === 'string') {
    const normalized = isVideoValue.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].includes(normalized)) return true;
    if (['false', '0', 'no', 'n'].includes(normalized)) return false;
  }
  const candidates = [item.path, item.filename, item.url, item.thumbnail_url];
  if (candidates.some((candidate) => isVideoPath(candidate))) {
    return true;
  }
  return looksLikeVideoThumbnail(item.thumbnail_url);
};
