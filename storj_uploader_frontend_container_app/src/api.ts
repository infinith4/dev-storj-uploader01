import axios from 'axios';
import { UploadResponse, HealthResponse, StatusResponse, TriggerUploadResponse } from './types';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8010';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 60000, // 60秒のタイムアウト
  withCredentials: true,
});

// レスポンスインターセプターでエラーハンドリング
api.interceptors.response.use(
  (response) => response,
  (error) => {
    console.error('API Error:', error);
    if (error.response) {
      // サーバーからのエラーレスポンス
      console.error('Response error:', error.response.data);
    } else if (error.request) {
      // リクエストが送信されたが、レスポンスがない
      console.error('Request error:', error.request);
    } else {
      // その他のエラー
      console.error('General error:', error.message);
    }
    return Promise.reject(error);
  }
);

export class StorjUploaderAPI {
  // 画像ファイル専用アップロード（複数）
  static async uploadImages(files: File[]): Promise<UploadResponse> {
    const formData = new FormData();
    files.forEach(file => {
      formData.append('files', file);
    });

    const response = await api.post<UploadResponse>('/upload', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  }

  // 画像ファイル専用アップロード（単一）
  static async uploadSingleImage(file: File): Promise<UploadResponse> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await api.post<UploadResponse>('/upload/single', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  }

  // 汎用ファイルアップロード（複数）
  static async uploadFiles(files: File[]): Promise<UploadResponse> {
    const formData = new FormData();
    files.forEach(file => {
      formData.append('files', file);
    });

    const response = await api.post<UploadResponse>('/upload/files', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  }

  // 汎用ファイルアップロード（単一）
  static async uploadSingleFile(file: File): Promise<UploadResponse> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await api.post<UploadResponse>('/upload/files/single', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    return response.data;
  }

  // ヘルスチェック
  static async health(): Promise<HealthResponse> {
    const response = await api.get<HealthResponse>('/health');
    return response.data;
  }

  // システムステータス取得
  static async status(): Promise<StatusResponse> {
    const response = await api.get<StatusResponse>('/status');
    return response.data;
  }

  // 手動Storjアップロード実行
  static async triggerUpload(): Promise<TriggerUploadResponse> {
    const response = await api.post<TriggerUploadResponse>('/trigger-upload');
    return response.data;
  }

  // 非同期Storjアップロード実行
  static async triggerUploadAsync(): Promise<TriggerUploadResponse> {
    const response = await api.post<TriggerUploadResponse>('/trigger-upload-async');
    return response.data;
  }
}

// ファイルタイプ判定ユーティリティ
export const getFileType = (file: File): 'image' | 'video' | 'file' => {
  if (file.type.startsWith('image/')) {
    return 'image';
  } else if (file.type.startsWith('video/')) {
    return 'video';
  } else {
    return 'file';
  }
};

// ファイルサイズフォーマット
export const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

// プレビューURL生成
export const createPreviewUrl = (file: File): string | null => {
  if (file.type.startsWith('image/')) {
    return URL.createObjectURL(file);
  }
  return null;
};