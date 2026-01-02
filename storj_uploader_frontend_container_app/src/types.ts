// API レスポンス型定義
export interface FileInfo {
  original_name: string;
  name: string;
  extension: string;
  size_bytes: number;
  size_mb: number;
}

export interface FileUploadResult {
  filename: string;
  saved_as?: string;
  status: 'success' | 'error' | 'skipped';
  message: string;
  file_info?: FileInfo;
}

export interface UploadResponse {
  message: string;
  results: FileUploadResult[];
}

export interface HealthResponse {
  status: string;
  timestamp: string;
  upload_target_dir: string;
  upload_target_exists: boolean;
}

export interface ApiInfo {
  upload_target_dir: string;
  temp_dir: string;
  files_in_target: number;
  files_in_temp: number;
  supported_image_formats: string[];
  max_file_size_mb: number;
  endpoints: Record<string, string>;
}

export interface StorjStatus {
  storj_app_available: boolean;
  storj_app_path: string;
  upload_target_dir: string;
  uploaded_dir: string;
  files_in_target: number;
  files_uploaded: number;
  target_dir_exists: boolean;
  uploaded_dir_exists: boolean;
}

export interface StatusResponse {
  api_info: ApiInfo;
  storj_status: StorjStatus;
}

export interface TriggerUploadResponse {
  status: 'success' | 'error' | 'no_files' | 'started';
  message: string;
  files_count?: number;
  files_processed?: number;
  files_to_process?: number;
  output?: string;
}

// UI 用の型定義
export interface UploadFile {
  id: string;
  file: File;
  preview?: string | null;
  progress: number;
  status: 'pending' | 'uploading' | 'processing' | 'success' | 'error';
  savedAs?: string;
  result?: FileUploadResult;
}

export type FileType = 'image' | 'video' | 'file';

export interface UploadStats {
  total: number;
  success: number;
  error: number;
  pending: number;
}

// Storj画像関連の型定義
export interface StorjImageItem {
  filename: string;
  path: string;
  size: number;
  modified_time: string;
  thumbnail_url?: string | null;
  url?: string | null;
  is_video?: boolean;
}

export interface StorjImageListResponse {
  success: boolean;
  images: StorjImageItem[];
  total_count: number;
  message?: string | null;
}
