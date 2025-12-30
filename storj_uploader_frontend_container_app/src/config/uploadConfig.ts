/**
 * Upload configuration constants
 */
export const UPLOAD_CONFIG = {
  /**
   * Maximum number of images allowed in upload queue
   */
  MAX_IMAGE_UPLOAD_LIMIT: 1000,

  /**
   * Maximum number of videos allowed in upload queue
   */
  MAX_VIDEO_UPLOAD_LIMIT: 100,

  /**
   * Maximum files per single upload operation
   */
  MAX_FILES_PER_UPLOAD: 10,

  /**
   * Warning threshold (percentage of limit)
   */
  WARNING_THRESHOLD: 0.8, // 80%
} as const;

export type UploadConfig = typeof UPLOAD_CONFIG;
