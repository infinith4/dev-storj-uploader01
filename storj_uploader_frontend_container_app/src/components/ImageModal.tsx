import React, { useEffect, useRef, useState } from 'react';
import { X, Download, ZoomIn, ZoomOut } from 'lucide-react';
import { StorjImageItem } from '../types';
import { StorjUploaderAPI } from '../api';
import { isVideoPath, resolveIsVideo } from '../utils/media';

interface ImageModalProps {
  image: StorjImageItem;
  isOpen: boolean;
  onClose: () => void;
}

const ImageModal: React.FC<ImageModalProps> = ({ image, isOpen, onClose }) => {
  const [isLoading, setIsLoading] = useState(true);
  const [zoom, setZoom] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [forceVideo, setForceVideo] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  const [isRetrying, setIsRetrying] = useState(false);
  const [mediaVersion, setMediaVersion] = useState(0);
  const retryTimeoutRef = useRef<number | null>(null);

  const MAX_RETRIES = 3;
  const RETRY_BASE_DELAY_MS = 1500;

  useEffect(() => {
    if (isOpen) {
      setIsLoading(true);
      setError(null);
      setZoom(1);
      setForceVideo(false);
      setRetryCount(0);
      setIsRetrying(false);
      setMediaVersion(0);
      // Prevent body scroll when modal is open
      document.body.style.overflow = 'hidden';
    } else {
      // Re-enable body scroll when modal is closed
      document.body.style.overflow = 'unset';
    }

    return () => {
      if (retryTimeoutRef.current !== null) {
        window.clearTimeout(retryTimeoutRef.current);
        retryTimeoutRef.current = null;
      }
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const isVideo = forceVideo || resolveIsVideo(image);
  const imageUrl = StorjUploaderAPI.getStorjImageUrl(image.path);
  const posterUrl = image.thumbnail_url || StorjUploaderAPI.getStorjThumbnailUrl(image.path);
  const mediaUrl = mediaVersion > 0 ? `${imageUrl}&retry=${mediaVersion}` : imageUrl;

  const clearRetryTimer = () => {
    if (retryTimeoutRef.current !== null) {
      window.clearTimeout(retryTimeoutRef.current);
      retryTimeoutRef.current = null;
    }
  };

  const handleDownload = () => {
    const link = document.createElement('a');
    link.href = imageUrl;
    link.download = image.filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleZoomIn = () => {
    setZoom(prev => Math.min(prev + 0.25, 3));
  };

  const handleZoomOut = () => {
    setZoom(prev => Math.max(prev - 0.25, 0.5));
  };

  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    const target = e.target as Element | null;
    if (!target) {
      onClose();
      return;
    }
    if (target.closest('[data-modal-media="true"]')) {
      return;
    }
    if (target.closest('[data-modal-controls="true"]')) {
      return;
    }
    onClose();
  };

  const probeMediaStatus = async (): Promise<number | null> => {
    try {
      const response = await fetch(imageUrl, { method: 'HEAD', cache: 'no-store' });
      return response.status;
    } catch (probeError) {
      console.error('Media probe failed:', probeError);
      return null;
    }
  };

  const handleMediaLoaded = () => {
    clearRetryTimer();
    setIsLoading(false);
    setIsRetrying(false);
    setError(null);
    setRetryCount(0);
  };

  const handleManualRetry = () => {
    clearRetryTimer();
    setIsLoading(true);
    setIsRetrying(false);
    setError(null);
    setRetryCount(0);
    setMediaVersion(prev => prev + 1);
  };

  const handleMediaError = async () => {
    clearRetryTimer();
    const status = await probeMediaStatus();

    if (status === 503 && retryCount < MAX_RETRIES) {
      const nextRetry = retryCount + 1;
      setRetryCount(nextRetry);
      setIsRetrying(true);
      setIsLoading(true);
      setError(null);

      const delay = RETRY_BASE_DELAY_MS * nextRetry;
      retryTimeoutRef.current = window.setTimeout(() => {
        setMediaVersion(prev => prev + 1);
      }, delay);
      return;
    }

    setIsLoading(false);
    setIsRetrying(false);
    if (status === 503) {
      setError('サーバーが一時的に利用できません（503）。しばらくしてから再試行してください。');
      return;
    }
    if (status) {
      setError(`HTTP ${status}`);
      return;
    }
    setError('ネットワークエラーが発生しました');
  };

  const formatFileSize = (bytes: number): string => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-90"
      onClick={handleBackdropClick}
    >
      {/* モーダルコンテンツ */}
      <div className="relative w-full h-full flex flex-col">
        {/* ヘッダー */}
        <div className="absolute top-0 left-0 right-0 z-10 bg-gradient-to-b from-black to-transparent p-4">
          <div className="flex items-center justify-between text-white">
            <div className="flex-1 pr-4">
              <h3 className="text-lg font-semibold truncate">{image.filename}</h3>
              <p className="text-sm text-gray-300">
                {formatFileSize(image.size)} • {formatDate(image.modified_time)}
              </p>
            </div>
            <div className="flex items-center space-x-2" data-modal-controls="true">
              {!isVideo && (
                <>
                  <button
                    onClick={handleZoomOut}
                    className="p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 transition-all"
                    title="ズームアウト"
                  >
                    <ZoomOut className="w-5 h-5" />
                  </button>
                  <button
                    onClick={handleZoomIn}
                    className="p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 transition-all"
                    title="ズームイン"
                  >
                    <ZoomIn className="w-5 h-5" />
                  </button>
                </>
              )}
              <button
                onClick={handleDownload}
                className="p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 transition-all"
                title="ダウンロード"
              >
                <Download className="w-5 h-5" />
              </button>
              <button
                onClick={onClose}
                className="p-2 rounded-full bg-gray-800 bg-opacity-50 hover:bg-opacity-75 transition-all"
                title="閉じる"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        {/* 画像コンテナ */}
        <div className="flex-1 flex items-center justify-center overflow-auto p-4">
          {isLoading && !error && (
            <div className="text-white text-center">
              <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-white mb-4"></div>
              <p>
                {isRetrying
                  ? `サーバーが一時的に利用できません（503）。再試行中 (${retryCount}/${MAX_RETRIES})...`
                  : `${isVideo ? '動画' : '画像'}を読み込み中...`}
              </p>
            </div>
          )}
          {error && (
            <div className="text-white text-center">
              <p className="text-red-400 mb-2">
                {isVideo ? '動画' : '画像'}の読み込みに失敗しました
              </p>
              <p className="text-sm text-gray-400">{error}</p>
              <button
                onClick={handleManualRetry}
                className="mt-4 px-4 py-2 text-sm rounded-md bg-gray-800 bg-opacity-70 hover:bg-opacity-90 transition-all"
              >
                再試行
              </button>
            </div>
          )}
          {isVideo ? (
            <video
              src={mediaUrl}
              poster={posterUrl}
              controls
              preload="metadata"
              playsInline
              className="max-w-full max-h-full"
              data-modal-media="true"
              style={{ display: isLoading || error ? 'none' : 'block' }}
              onLoadedData={handleMediaLoaded}
              onError={() => {
                void handleMediaError();
              }}
            />
          ) : (
            <img
              src={mediaUrl}
              alt={image.filename}
              className="max-w-full max-h-full object-contain transition-transform duration-200"
              data-modal-media="true"
              style={{
                transform: `scale(${zoom})`,
                display: isLoading || error ? 'none' : 'block',
              }}
              onLoad={handleMediaLoaded}
              onError={() => {
                if (!forceVideo && isVideoPath(imageUrl)) {
                  setForceVideo(true);
                  setIsLoading(true);
                  setError(null);
                  return;
                }
                void handleMediaError();
              }}
            />
          )}
        </div>

        {/* フッター（ズーム表示） */}
        {!isVideo && (
          <div className="absolute bottom-0 left-0 right-0 z-10 bg-gradient-to-t from-black to-transparent p-4">
            <div className="text-center text-white text-sm">
              ズーム: {Math.round(zoom * 100)}%
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ImageModal;
