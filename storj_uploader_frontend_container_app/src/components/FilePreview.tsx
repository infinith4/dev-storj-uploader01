import React from 'react';
import { X, CheckCircle, AlertCircle, Clock, Image, Video, FileText } from 'lucide-react';
import { UploadFile } from '../types';
import { formatFileSize, getFileType } from '../api';

interface FilePreviewProps {
  file: UploadFile;
  onRemove: (id: string) => void;
  showRemove?: boolean;
}

const FilePreview: React.FC<FilePreviewProps> = ({
  file,
  onRemove,
  showRemove = true,
}) => {
  const fileType = getFileType(file.file);

  const getStatusIcon = () => {
    switch (file.status) {
      case 'success':
        return <CheckCircle className="w-5 h-5 text-green-500" />;
      case 'error':
        return <AlertCircle className="w-5 h-5 text-red-500" />;
      case 'processing':
        return <Clock className="w-5 h-5 text-orange-500 animate-spin" />;
      case 'uploading':
        return <Clock className="w-5 h-5 text-blue-500 animate-spin" />;
      default:
        return <Clock className="w-5 h-5 text-gray-400" />;
    }
  };

  const getFileIcon = () => {
    switch (fileType) {
      case 'image':
        return <Image className="w-8 h-8 text-blue-500" />;
      case 'video':
        return <Video className="w-8 h-8 text-purple-500" />;
      default:
        return <FileText className="w-8 h-8 text-green-500" />;
    }
  };

  const getStatusColor = () => {
    switch (file.status) {
      case 'success':
        return 'border-green-200 bg-green-50';
      case 'error':
        return 'border-red-200 bg-red-50';
      case 'processing':
        return 'border-orange-200 bg-orange-50';
      case 'uploading':
        return 'border-blue-200 bg-blue-50';
      default:
        return 'border-gray-200 bg-gray-50';
    }
  };

  return (
    <div
      className={`relative border rounded-lg p-4 ${getStatusColor()}`}
      data-testid="file-preview"
      data-status={file.status}
      data-filename={file.file.name}
    >
      {showRemove && (
        <button
          onClick={() => onRemove(file.id)}
          className="absolute top-2 right-2 p-1 rounded-full bg-white shadow-md hover:bg-gray-100 transition-colors"
          disabled={file.status === 'uploading'}
        >
          <X className="w-4 h-4 text-gray-600" />
        </button>
      )}

      <div className="flex items-start space-x-3">
        <div className="flex-shrink-0">
          {file.preview && file.preview !== null ? (
            <img
              src={file.preview}
              alt={file.file.name}
              className="w-16 h-16 object-cover rounded-md"
            />
          ) : (
            <div className="w-16 h-16 bg-gray-100 rounded-md flex items-center justify-center">
              {getFileIcon()}
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between mb-1">
            <p className="text-sm font-medium text-gray-900 truncate">
              {file.file.name}
            </p>
            {getStatusIcon()}
          </div>

          <p className="text-xs text-gray-500 mb-2">
            {formatFileSize(file.file.size)} • {fileType}
          </p>

          {(file.status === 'uploading' || file.status === 'processing') && (
            <div className="w-full bg-gray-200 rounded-full h-2 mb-2">
              <div
                className={`h-2 rounded-full transition-all duration-300 ${
                  file.status === 'processing' ? 'bg-orange-500' : 'bg-blue-500'
                }`}
                style={{ width: `${file.progress}%` }}
              />
            </div>
          )}

          {file.result && (
            <div className="text-xs">
              {file.result.status === 'success' ? (
                <p className="text-green-600">
                  ✓ {file.result.message}
                </p>
              ) : (
                <p className="text-red-600">
                  ✗ {file.result.message}
                </p>
              )}
            </div>
          )}
          {file.status === 'processing' && !file.result && (
            <p className="text-xs text-orange-700">Storj への反映待ち...</p>
          )}
        </div>
      </div>
    </div>
  );
};

export default FilePreview;
