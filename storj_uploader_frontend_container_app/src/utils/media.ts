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

const isVideoPath = (path: string | null | undefined): boolean => {
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
  if (typeof isVideoValue === 'string') {
    const normalized = isVideoValue.toLowerCase();
    if (normalized === 'true') return true;
    if (normalized === 'false') return false;
  }
  return isVideoPath(item.path || item.filename);
};
