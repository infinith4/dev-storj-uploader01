import React, { useState, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { Upload as UploadIcon } from 'lucide-react';
import FileDropzone from './FileDropzone';
import FilePreview from './FilePreview';
import { UploadFile, FileType, UploadResponse } from '../types';
import { StorjUploaderAPI, createPreviewUrl } from '../api';

interface UploaderTabProps {
  type: 'image' | 'video' | 'file';
  title: string;
  description: string;
  acceptedTypes: FileType[];
  maxFiles?: number;
}

const UploaderTab: React.FC<UploaderTabProps> = ({
  type,
  title,
  description,
  acceptedTypes,
  maxFiles = 10,
}) => {
  const [files, setFiles] = useState<UploadFile[]>([]);
  const [isUploading, setIsUploading] = useState(false);

  const addFiles = useCallback((newFiles: File[]) => {
    const uploadFiles: UploadFile[] = newFiles.map(file => ({
      id: uuidv4(),
      file,
      preview: createPreviewUrl(file),
      progress: 0,
      status: 'pending',
    }));

    setFiles(prev => [...prev, ...uploadFiles]);
  }, []);

  const removeFile = useCallback((id: string) => {
    setFiles(prev => {
      const file = prev.find(f => f.id === id);
      if (file?.preview && file.preview !== null) {
        URL.revokeObjectURL(file.preview);
      }
      return prev.filter(f => f.id !== id);
    });
  }, []);

  const uploadFiles = async () => {
    const pendingFiles = files.filter(f => f.status === 'pending');
    if (pendingFiles.length === 0) return;

    setIsUploading(true);

    try {
      // ファイルを一括でアップロード
      const filesToUpload = pendingFiles.map(f => f.file);

      // アップロード中のステータス更新
      setFiles(prev => prev.map(f =>
        pendingFiles.some(pf => pf.id === f.id)
          ? { ...f, status: 'uploading' as const, progress: 50 }
          : f
      ));

      let response: UploadResponse;
      if (type === 'image') {
        response = filesToUpload.length === 1
          ? await StorjUploaderAPI.uploadSingleImage(filesToUpload[0])
          : await StorjUploaderAPI.uploadImages(filesToUpload);
      } else {
        response = filesToUpload.length === 1
          ? await StorjUploaderAPI.uploadSingleFile(filesToUpload[0])
          : await StorjUploaderAPI.uploadFiles(filesToUpload);
      }

      // 結果をファイルにマッピング
      setFiles(prev => prev.map(f => {
        const pendingFile = pendingFiles.find(pf => pf.id === f.id);
        if (!pendingFile) return f;

        const result = response.results.find(r => r.filename === pendingFile.file.name);
        if (result) {
          return {
            ...f,
            status: result.status as 'success' | 'error',
            progress: 100,
            result,
          };
        }

        return {
          ...f,
          status: 'error' as const,
          progress: 100,
          result: {
            filename: pendingFile.file.name,
            status: 'error' as const,
            message: 'アップロードに失敗しました',
          },
        };
      }));

    } catch (error) {
      console.error('Upload error:', error);

      // エラー時は全ての pending ファイルをエラー状態に
      setFiles(prev => prev.map(f =>
        pendingFiles.some(pf => pf.id === f.id)
          ? {
              ...f,
              status: 'error' as const,
              progress: 0,
              result: {
                filename: f.file.name,
                status: 'error' as const,
                message: 'ネットワークエラーが発生しました',
              }
            }
          : f
      ));
    } finally {
      setIsUploading(false);
    }
  };

  const clearFiles = () => {
    files.forEach(file => {
      if (file.preview && file.preview !== null) {
        URL.revokeObjectURL(file.preview);
      }
    });
    setFiles([]);
  };

  const pendingCount = files.filter(f => f.status === 'pending').length;
  const successCount = files.filter(f => f.status === 'success').length;
  const errorCount = files.filter(f => f.status === 'error').length;

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="text-center">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">{title}</h2>
        <p className="text-gray-600 mb-4">{description}</p>
      </div>

      {/* ドロップゾーン */}
      <FileDropzone
        onFilesAdded={addFiles}
        acceptedTypes={acceptedTypes}
        maxFiles={maxFiles}
        disabled={isUploading}
      />

      {/* ファイルリスト */}
      {files.length > 0 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-4 text-sm text-gray-600">
              <span>総数: {files.length}</span>
              {successCount > 0 && <span className="text-green-600">成功: {successCount}</span>}
              {errorCount > 0 && <span className="text-red-600">エラー: {errorCount}</span>}
              {pendingCount > 0 && <span className="text-blue-600">待機: {pendingCount}</span>}
            </div>

            <div className="flex gap-2">
              <button
                onClick={clearFiles}
                disabled={isUploading}
                className="px-4 py-2 text-sm border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                クリア
              </button>
              {pendingCount > 0 && (
                <button
                  onClick={uploadFiles}
                  disabled={isUploading}
                  className="px-4 py-2 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                >
                  <UploadIcon className="w-4 h-4" />
                  {isUploading ? 'アップロード中...' : `アップロード (${pendingCount})`}
                </button>
              )}
            </div>
          </div>

          {/* ファイルプレビューリスト */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {files.map(file => (
              <FilePreview
                key={file.id}
                file={file}
                onRemove={removeFile}
                showRemove={!isUploading}
              />
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default UploaderTab;