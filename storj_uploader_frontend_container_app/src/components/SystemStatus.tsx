import React, { useState, useEffect } from 'react';
import { RefreshCw, Server, Cloud, CheckCircle, AlertTriangle, Upload } from 'lucide-react';
import { StatusResponse, TriggerUploadResponse } from '../types';
import { StorjUploaderAPI } from '../api';

const SystemStatus: React.FC = () => {
  const [status, setStatus] = useState<StatusResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploadLoading, setUploadLoading] = useState(false);
  const [uploadResult, setUploadResult] = useState<TriggerUploadResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = async () => {
    try {
      setLoading(true);
      setError(null);

      // APIベースURLの確認
      console.log('Fetching status from:', process.env.REACT_APP_API_URL || 'http://localhost:8010');

      const data = await StorjUploaderAPI.status();
      setStatus(data);
      console.log('Status fetched successfully:', data);
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || err.message || 'ステータスの取得に失敗しました';
      setError(errorMessage);
      console.error('Status fetch error:', {
        message: err.message,
        response: err.response?.data,
        status: err.response?.status,
        url: err.config?.url,
      });
    } finally {
      setLoading(false);
    }
  };

  const triggerUpload = async (async = false) => {
    try {
      setUploadLoading(true);
      setUploadResult(null);
      const result = async
        ? await StorjUploaderAPI.triggerUploadAsync()
        : await StorjUploaderAPI.triggerUpload();
      setUploadResult(result);
      // アップロード後にステータスを更新
      setTimeout(fetchStatus, 1000);
    } catch (err) {
      setUploadResult({
        status: 'error',
        message: 'アップロードの実行に失敗しました',
      });
      console.error('Upload trigger error:', err);
    } finally {
      setUploadLoading(false);
    }
  };

  useEffect(() => {
    fetchStatus();
    // 30秒ごとにステータスを更新
    const interval = setInterval(fetchStatus, 30000);
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-center">
          <RefreshCw className="w-6 h-6 animate-spin text-blue-500" />
          <span className="ml-2 text-gray-600">ステータスを読み込み中...</span>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-white rounded-lg shadow-md p-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center text-red-600">
            <AlertTriangle className="w-5 h-5 mr-2" />
            <span>{error}</span>
          </div>
          <button
            onClick={fetchStatus}
            className="px-3 py-1 text-sm bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            再試行
          </button>
        </div>
      </div>
    );
  }

  if (!status) return null;

  return (
    <div className="bg-white rounded-lg shadow-md p-6 space-y-6">
      {/* ヘッダー */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900 flex items-center">
          <Server className="w-5 h-5 mr-2" />
          システムステータス
        </h3>
        <button
          onClick={fetchStatus}
          disabled={loading}
          className="p-2 text-gray-500 hover:text-gray-700 rounded-md hover:bg-gray-100"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* API情報 */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="space-y-3">
          <h4 className="font-medium text-gray-900">API サーバー</h4>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-600">アップロード対象</span>
              <span className="font-medium">{status.api_info.files_in_target} ファイル</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">一時ファイル</span>
              <span className="font-medium">{status.api_info.files_in_temp} ファイル</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">最大ファイルサイズ</span>
              <span className="font-medium">{status.api_info.max_file_size_mb} MB</span>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          <h4 className="font-medium text-gray-900 flex items-center">
            <Cloud className="w-4 h-4 mr-1" />
            Storj Container App
          </h4>
          <div className="space-y-2 text-sm">
            <div className="flex items-center justify-between">
              <span className="text-gray-600">ステータス</span>
              <div className="flex items-center">
                {status.storj_status.storj_app_available ? (
                  <CheckCircle className="w-4 h-4 text-green-500 mr-1" />
                ) : (
                  <AlertTriangle className="w-4 h-4 text-red-500 mr-1" />
                )}
                <span className={status.storj_status.storj_app_available ? 'text-green-600' : 'text-red-600'}>
                  {status.storj_status.storj_app_available ? '利用可能' : '利用不可'}
                </span>
              </div>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">アップロード予定</span>
              <span className="font-medium">{status.storj_status.files_in_target} ファイル</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">アップロード済み</span>
              <span className="font-medium text-green-600">{status.storj_status.files_uploaded} ファイル</span>
            </div>
          </div>
        </div>
      </div>

      {/* アップロード実行ボタン */}
      {status.storj_status.files_in_target > 0 && (
        <div className="border-t pt-4">
          <div className="flex flex-col sm:flex-row gap-3">
            <button
              onClick={() => triggerUpload(false)}
              disabled={uploadLoading}
              className="flex-1 flex items-center justify-center px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Upload className="w-4 h-4 mr-2" />
              手動アップロード実行
            </button>
            <button
              onClick={() => triggerUpload(true)}
              disabled={uploadLoading}
              className="flex-1 flex items-center justify-center px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Upload className="w-4 h-4 mr-2" />
              非同期アップロード実行
            </button>
          </div>
        </div>
      )}

      {/* アップロード結果 */}
      {uploadResult && (
        <div className={`p-3 rounded-md ${
          uploadResult.status === 'success' || uploadResult.status === 'started'
            ? 'bg-green-50 text-green-800'
            : uploadResult.status === 'no_files'
            ? 'bg-yellow-50 text-yellow-800'
            : 'bg-red-50 text-red-800'
        }`}>
          <p className="text-sm font-medium">{uploadResult.message}</p>
          {uploadResult.files_processed && (
            <p className="text-xs mt-1">処理ファイル数: {uploadResult.files_processed}</p>
          )}
          {uploadResult.output && (
            <details className="mt-2">
              <summary className="text-xs cursor-pointer">詳細を表示</summary>
              <pre className="text-xs mt-1 whitespace-pre-wrap">{uploadResult.output}</pre>
            </details>
          )}
        </div>
      )}
    </div>
  );
};

export default SystemStatus;