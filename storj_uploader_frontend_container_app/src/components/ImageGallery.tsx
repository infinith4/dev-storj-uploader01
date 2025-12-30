import React, { useEffect, useState } from 'react';
import { RefreshCw, AlertCircle, Image as ImageIcon } from 'lucide-react';
import { StorjImageItem } from '../types';
import { StorjUploaderAPI } from '../api';
import ImageModal from './ImageModal';

const ImageGallery: React.FC = () => {
  const [images, setImages] = useState<StorjImageItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedImage, setSelectedImage] = useState<StorjImageItem | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const loadImages = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await StorjUploaderAPI.getStorjImages({ limit: 100, offset: 0 });

      if (response.success) {
        const sortedImages = [...response.images].sort((a, b) => {
          const aTime = Date.parse(a.modified_time.replace(' ', 'T'));
          const bTime = Date.parse(b.modified_time.replace(' ', 'T'));
          if (Number.isNaN(aTime) || Number.isNaN(bTime)) {
            return b.modified_time.localeCompare(a.modified_time);
          }
          return bTime - aTime;
        });
        setImages(sortedImages);
      } else {
        setError(response.message || '画像の取得に失敗しました');
      }
    } catch (err) {
      setError('画像の取得中にエラーが発生しました');
      console.error('Error loading images:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadImages();
  }, []);

  const handleImageClick = (image: StorjImageItem) => {
    setSelectedImage(image);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedImage(null);
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
    return date.toLocaleDateString('ja-JP', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
  };

  return (
    <div className="space-y-6">
      {/* ヘッダー */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Storj画像一覧</h2>
          <p className="text-sm text-gray-600 mt-1">
            Storjに保存されている画像を一覧表示します。画像をタップするとフルサイズで表示されます。
          </p>
        </div>
        <button
          onClick={loadImages}
          disabled={isLoading}
          data-testid="gallery-refresh"
          className={`
            flex items-center px-4 py-2 rounded-lg border transition-all
            ${isLoading
              ? 'bg-gray-100 text-gray-400 border-gray-300 cursor-not-allowed'
              : 'bg-white text-blue-600 border-blue-600 hover:bg-blue-50'
            }
          `}
        >
          <RefreshCw className={`w-4 h-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
          更新
        </button>
      </div>

      {/* ローディング状態 */}
      {isLoading && (
        <div className="flex items-center justify-center py-12" data-testid="gallery-loading">
          <div className="text-center">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mb-4"></div>
            <p className="text-gray-600">画像を読み込み中...</p>
          </div>
        </div>
      )}

      {/* エラー状態 */}
      {!isLoading && error && (
        <div className="flex items-center justify-center py-12" data-testid="gallery-error">
          <div className="text-center">
            <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
            <p className="text-red-600 font-medium mb-2">エラーが発生しました</p>
            <p className="text-gray-600 text-sm">{error}</p>
            <button
              onClick={loadImages}
              className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              再試行
            </button>
          </div>
        </div>
      )}

      {/* 画像がない場合 */}
      {!isLoading && !error && images.length === 0 && (
        <div className="flex items-center justify-center py-12" data-testid="gallery-empty">
          <div className="text-center">
            <ImageIcon className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600 font-medium mb-2">画像がありません</p>
            <p className="text-gray-500 text-sm">Storjにアップロードされた画像がここに表示されます</p>
          </div>
        </div>
      )}

      {/* 画像グリッド */}
      {!isLoading && !error && images.length > 0 && (
        <>
          <div className="mb-4 text-sm text-gray-600">
            {images.length}件の画像が見つかりました
          </div>
          <div
            className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4"
            data-testid="gallery-grid"
          >
            {images.map((image, index) => (
              <div
                key={`${image.path}-${index}`}
                data-testid="gallery-item"
                className="group relative aspect-square bg-gray-100 rounded-lg overflow-hidden cursor-pointer transition-all hover:shadow-lg hover:scale-105"
                onClick={() => handleImageClick(image)}
              >
                {/* サムネイル画像 */}
                <img
                  src={StorjUploaderAPI.getStorjThumbnailUrl(image.path)}
                  alt={image.filename}
                  className="w-full h-full object-cover"
                  loading="lazy"
                />

                {/* ホバー時のオーバーレイ */}
                <div className="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-all flex items-end p-2">
                  <div className="transform translate-y-full group-hover:translate-y-0 transition-transform duration-200">
                    <p className="text-white text-xs font-medium truncate mb-1">
                      {image.filename}
                    </p>
                    <div className="flex items-center justify-between text-white text-xs">
                      <span>{formatFileSize(image.size)}</span>
                      <span>{formatDate(image.modified_time)}</span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      {/* 画像モーダル */}
      {selectedImage && (
        <ImageModal
          image={selectedImage}
          isOpen={isModalOpen}
          onClose={handleCloseModal}
        />
      )}
    </div>
  );
};

export default ImageGallery;
