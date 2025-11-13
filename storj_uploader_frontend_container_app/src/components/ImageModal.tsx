import React, { useEffect, useState } from 'react';
import { X, Download, ZoomIn, ZoomOut } from 'lucide-react';
import { StorjImageItem } from '../types';
import { StorjUploaderAPI } from '../api';

interface ImageModalProps {
  image: StorjImageItem;
  isOpen: boolean;
  onClose: () => void;
}

const ImageModal: React.FC<ImageModalProps> = ({ image, isOpen, onClose }) => {
  const [isLoading, setIsLoading] = useState(true);
  const [zoom, setZoom] = useState(1);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      setIsLoading(true);
      setError(null);
      setZoom(1);
      // Prevent body scroll when modal is open
      document.body.style.overflow = 'hidden';
    } else {
      // Re-enable body scroll when modal is closed
      document.body.style.overflow = 'unset';
    }

    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  const imageUrl = StorjUploaderAPI.getStorjImageUrl(image.path);

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
    if (e.target === e.currentTarget) {
      onClose();
    }
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
            <div className="flex items-center space-x-2">
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
              <p>画像を読み込み中...</p>
            </div>
          )}
          {error && (
            <div className="text-white text-center">
              <p className="text-red-400 mb-2">画像の読み込みに失敗しました</p>
              <p className="text-sm text-gray-400">{error}</p>
            </div>
          )}
          <img
            src={imageUrl}
            alt={image.filename}
            className="max-w-full max-h-full object-contain transition-transform duration-200"
            style={{
              transform: `scale(${zoom})`,
              display: isLoading || error ? 'none' : 'block',
            }}
            onLoad={() => setIsLoading(false)}
            onError={() => {
              setIsLoading(false);
              setError('画像の読み込みに失敗しました');
            }}
          />
        </div>

        {/* フッター（ズーム表示） */}
        <div className="absolute bottom-0 left-0 right-0 z-10 bg-gradient-to-t from-black to-transparent p-4">
          <div className="text-center text-white text-sm">
            ズーム: {Math.round(zoom * 100)}%
          </div>
        </div>
      </div>
    </div>
  );
};

export default ImageModal;
