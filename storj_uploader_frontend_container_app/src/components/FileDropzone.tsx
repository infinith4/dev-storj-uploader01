import React, { useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { Upload, Image, Video, FileText } from 'lucide-react';
import { FileType } from '../types';
import { getFileType } from '../api';

interface FileDropzoneProps {
  onFilesAdded: (files: File[]) => void;
  acceptedTypes?: FileType[];
  maxFiles?: number;
  disabled?: boolean;
  className?: string;
}

const FileDropzone: React.FC<FileDropzoneProps> = ({
  onFilesAdded,
  acceptedTypes = ['image', 'video', 'file'],
  maxFiles = 10,
  disabled = false,
  className = '',
}) => {
  const getAcceptConfig = () => {
    const config: { [key: string]: string[] } = {};

    if (acceptedTypes.includes('image')) {
      config['image/*'] = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.heic', '.heif'];
    }
    if (acceptedTypes.includes('video')) {
      config['video/*'] = ['.mp4', '.mov', '.avi', '.mkv', '.wmv', '.flv', '.webm'];
    }
    if (acceptedTypes.includes('file')) {
      // すべてのファイル形式を許可
      config['*'] = [];
    }

    return config;
  };

  const onDrop = useCallback(
    (acceptedFiles: File[]) => {
      if (acceptedFiles.length > 0) {
        onFilesAdded(acceptedFiles);
      }
    },
    [onFilesAdded]
  );

  const { getRootProps, getInputProps, isDragActive, isDragReject } = useDropzone({
    onDrop,
    accept: getAcceptConfig(),
    maxFiles,
    disabled,
    multiple: maxFiles > 1,
  });

  const getIcon = () => {
    if (acceptedTypes.length === 1) {
      switch (acceptedTypes[0]) {
        case 'image':
          return <Image className="w-12 h-12 text-blue-400" />;
        case 'video':
          return <Video className="w-12 h-12 text-purple-400" />;
        case 'file':
          return <FileText className="w-12 h-12 text-green-400" />;
      }
    }
    return <Upload className="w-12 h-12 text-gray-400" />;
  };

  const getMessage = () => {
    if (disabled) return 'アップロードが無効です';
    if (isDragReject) return 'このファイル形式はサポートされていません';
    if (isDragActive) return 'ファイルをドロップしてください';

    const typeNames = {
      image: '画像',
      video: '動画',
      file: 'ファイル',
    };

    const typeLabels = acceptedTypes.map(type => typeNames[type]).join('・');

    return `${typeLabels}をドラッグ&ドロップするか、クリックして選択`;
  };

  const getBorderColor = () => {
    if (disabled) return 'border-gray-300';
    if (isDragReject) return 'border-red-400';
    if (isDragActive) return 'border-blue-400';
    return 'border-gray-400';
  };

  const getBackgroundColor = () => {
    if (disabled) return 'bg-gray-50';
    if (isDragReject) return 'bg-red-50';
    if (isDragActive) return 'bg-blue-50';
    return 'bg-white hover:bg-gray-50';
  };

  return (
    <div
      {...getRootProps()}
      className={`
        w-full p-8 border-2 border-dashed rounded-lg cursor-pointer transition-all duration-200
        ${getBorderColor()}
        ${getBackgroundColor()}
        ${disabled ? 'cursor-not-allowed' : 'cursor-pointer'}
        ${className}
      `}
    >
      <input {...getInputProps()} />
      <div className="flex flex-col items-center justify-center text-center space-y-4">
        {getIcon()}
        <div>
          <p className="text-lg font-medium text-gray-700 mb-2">
            {getMessage()}
          </p>
          <p className="text-sm text-gray-500">
            最大 {maxFiles} ファイルまで選択可能
          </p>
          {acceptedTypes.includes('image') && (
            <p className="text-xs text-gray-400 mt-1">
              対応画像形式: JPEG, PNG, GIF, BMP, WebP, HEIC, HEIF
            </p>
          )}
          {acceptedTypes.includes('video') && (
            <p className="text-xs text-gray-400 mt-1">
              対応動画形式: MP4, MOV, AVI, MKV, WMV, FLV, WebM
            </p>
          )}
          {acceptedTypes.includes('file') && (
            <p className="text-xs text-gray-400 mt-1">
              すべてのファイル形式に対応
            </p>
          )}
        </div>
      </div>
    </div>
  );
};

export default FileDropzone;