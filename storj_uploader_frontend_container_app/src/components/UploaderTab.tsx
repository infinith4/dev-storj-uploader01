import React, { useState, useCallback, useMemo } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { Upload as UploadIcon, AlertTriangle } from 'lucide-react';
import FileDropzone from './FileDropzone';
import FilePreview from './FilePreview';
import { UploadFile, FileType, UploadResponse } from '../types';
import { StorjUploaderAPI, createPreviewUrl } from '../api';
import { UPLOAD_CONFIG } from '../config/uploadConfig';

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

  // Calculate upload limit based on type
  const uploadLimit = useMemo(() => {
    if (type === 'video') {
      return UPLOAD_CONFIG.MAX_VIDEO_UPLOAD_LIMIT;
    } else if (type === 'image') {
      return UPLOAD_CONFIG.MAX_IMAGE_UPLOAD_LIMIT;
    }
    // For 'file' type, use image limit as it may contain both
    return UPLOAD_CONFIG.MAX_IMAGE_UPLOAD_LIMIT;
  }, [type]);

  // Check if approaching or exceeding limit
  const limitStatus = useMemo(() => {
    const pendingCount = files.filter(f => f.status === 'pending').length;
    const isExceeded = pendingCount > uploadLimit;
    const isWarning = pendingCount > uploadLimit * UPLOAD_CONFIG.WARNING_THRESHOLD;

    return {
      count: pendingCount,
      limit: uploadLimit,
      isExceeded,
      isWarning: !isExceeded && isWarning,
      percentage: (pendingCount / uploadLimit) * 100,
    };
  }, [files, uploadLimit]);

  const addFiles = useCallback((newFiles: File[]) => {
    const pendingCount = files.filter(f => f.status === 'pending').length;

    // Check if adding these files would exceed the limit
    if (pendingCount + newFiles.length > uploadLimit) {
      const allowedCount = uploadLimit - pendingCount;
      if (allowedCount <= 0) {
        alert(`アップロード上限（${uploadLimit}件）に達しています。これ以上ファイルを追加できません。`);
        return;
      }

      alert(`アップロード上限（${uploadLimit}件）を超えるため、${allowedCount}件のみ追加します。`);
      newFiles = newFiles.slice(0, allowedCount);
    }

    const uploadFiles: UploadFile[] = newFiles.map(file => ({
      id: uuidv4(),
      file,
      preview: createPreviewUrl(file),
      progress: 0,
      status: 'pending',
    }));

    setFiles(prev => [...prev, ...uploadFiles]);
  }, [files, uploadLimit]);

  const removeFile = useCallback((id: string) => {
    setFiles(prev => {
      const file = prev.find(f => f.id === id);
      if (file?.preview && file.preview !== null) {
        URL.revokeObjectURL(file.preview);
      }
      return prev.filter(f => f.id !== id);
    });
  }, []);

  const pollStorjStatuses = async (savedAsList: string[]) => {
    if (savedAsList.length === 0) return;

    const maxAttempts = 30; // 約60秒
    const intervalMs = 2000;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        const statusMap = await StorjUploaderAPI.getUploadStatuses(savedAsList);
        let allDone = true;

        setFiles(prev => prev.map(f => {
          if (!f.savedAs) return f;
          const status = statusMap[f.savedAs];
          if (!status) return f;
          if (status === 'uploaded') {
            return { ...f, status: 'success', progress: 100 };
          }
          if (status === 'queued' || status === 'processing') {
            allDone = false;
            return { ...f, status: 'processing', progress: Math.max(f.progress, 90) };
          }
          // unknown -> keep processing but allow loop to continue
          allDone = false;
          return { ...f, status: 'processing', progress: Math.max(f.progress, 90) };
        }));

        if (allDone) return;
      } catch (error) {
        console.error('Status polling error:', error);
        // 失敗時はリトライ
      }

      await new Promise(resolve => setTimeout(resolve, intervalMs));
    }

    // タイムアウト時は処理中を成功扱いに
    setFiles(prev => prev.map(f => {
      if (f.status === 'processing') {
        return { ...f, status: 'success', progress: 100 };
      }
      return f;
    }));
  };

  const uploadFiles = async () => {
    const pendingFiles = files.filter(f => f.status === 'pending');
    if (pendingFiles.length === 0) return;

    setIsUploading(true);

    try {
      const processingNames: string[] = [];
      const updateFile = (id: string, updater: (f: UploadFile) => UploadFile) => {
        setFiles(prev => prev.map(f => f.id === id ? updater(f) : f));
      };

      for (const pending of pendingFiles) {
        updateFile(pending.id, (f) => ({ ...f, status: 'uploading', progress: 0 }));

        const onProgress = (progress: number) => {
          updateFile(pending.id, (f) => ({ ...f, progress, status: 'uploading' }));
        };

        try {
          const response: UploadResponse = type === 'image'
            ? await StorjUploaderAPI.uploadSingleImageWithProgress(pending.file, onProgress)
            : await StorjUploaderAPI.uploadSingleFileWithProgress(pending.file, onProgress);

          const result = response.results?.[0];
          if (result) {
            if (result.status !== 'error' && result.saved_as) {
              updateFile(pending.id, (f) => ({
                ...f,
                status: 'processing',
                progress: Math.max(f.progress, 90),
                result,
                savedAs: result.saved_as,
              }));
              processingNames.push(result.saved_as);
            } else {
              updateFile(pending.id, (f) => ({
                ...f,
                status: result.status === 'error' ? 'error' : 'success',
                progress: 100,
                result,
                savedAs: result.saved_as || f.savedAs,
              }));
            }
          } else {
            updateFile(pending.id, (f) => ({
              ...f,
              status: 'error',
              progress: 100,
              result: {
                filename: pending.file.name,
                status: 'error',
                message: 'アップロードに失敗しました',
              },
            }));
          }
        } catch (error) {
          console.error('Upload error:', error);
          updateFile(pending.id, (f) => ({
            ...f,
            status: 'error',
            progress: 100,
            result: {
              filename: pending.file.name,
              status: 'error',
              message: 'ネットワークエラーが発生しました',
            }
          }));
        }
      }

      // Storj反映完了をポーリング
      await pollStorjStatuses(processingNames);

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

      {/* Upload Limit Warning */}
      {(limitStatus.isWarning || limitStatus.isExceeded) && (
        <div className={`p-4 rounded-lg border ${
          limitStatus.isExceeded
            ? 'bg-red-50 border-red-200'
            : 'bg-yellow-50 border-yellow-200'
        }`}>
          <div className="flex items-start gap-3">
            <AlertTriangle className={`w-5 h-5 flex-shrink-0 ${
              limitStatus.isExceeded ? 'text-red-600' : 'text-yellow-600'
            }`} />
            <div className="flex-1">
              <p className={`font-semibold ${
                limitStatus.isExceeded ? 'text-red-800' : 'text-yellow-800'
              }`}>
                {limitStatus.isExceeded
                  ? 'アップロード上限を超えています'
                  : 'アップロード上限に近づいています'}
              </p>
              <p className={`text-sm mt-1 ${
                limitStatus.isExceeded ? 'text-red-700' : 'text-yellow-700'
              }`}>
                現在の待機ファイル数: {limitStatus.count} / {limitStatus.limit} ({limitStatus.percentage.toFixed(1)}%)
              </p>
              {limitStatus.isExceeded && (
                <p className="text-sm mt-2 text-red-700">
                  上限を超えたファイルはアップロードできません。不要なファイルを削除してください。
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Upload Quota Display */}
      <div className="text-center">
        <p className={`text-sm ${
          limitStatus.isExceeded ? 'text-red-600 font-semibold' :
          limitStatus.isWarning ? 'text-yellow-600 font-semibold' :
          'text-gray-500'
        }`}>
          アップロード待機数: {limitStatus.count} / {limitStatus.limit}
        </p>
      </div>

      {/* ドロップゾーン */}
      <FileDropzone
        onFilesAdded={addFiles}
        acceptedTypes={acceptedTypes}
        maxFiles={maxFiles}
        disabled={isUploading || limitStatus.isExceeded}
        dropzoneTestId={`${type}-dropzone`}
        inputTestId={`${type}-file-input`}
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
                  disabled={isUploading || limitStatus.isExceeded}
                  data-testid={`${type}-upload-button`}
                  className="px-4 py-2 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                  title={limitStatus.isExceeded ? 'アップロード上限を超えています' : ''}
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
