import React, { useState } from 'react';
import { Image, Video, FileText, BarChart3 } from 'lucide-react';
import UploaderTab from './components/UploaderTab';
import SystemStatus from './components/SystemStatus';

type TabType = 'images' | 'videos' | 'files' | 'status';

interface Tab {
  id: TabType;
  label: string;
  icon: React.ReactNode;
  description: string;
}

const tabs: Tab[] = [
  {
    id: 'images',
    label: '画像',
    icon: <Image className="w-5 h-5" />,
    description: '写真・画像ファイルをアップロード',
  },
  {
    id: 'videos',
    label: '動画',
    icon: <Video className="w-5 h-5" />,
    description: '動画ファイルをアップロード',
  },
  {
    id: 'files',
    label: 'ファイル',
    icon: <FileText className="w-5 h-5" />,
    description: 'すべてのファイル形式に対応',
  },
  {
    id: 'status',
    label: 'ステータス',
    icon: <BarChart3 className="w-5 h-5" />,
    description: 'システム状態を確認',
  },
];

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabType>('images');

  const renderTabContent = () => {
    switch (activeTab) {
      case 'images':
        return (
          <UploaderTab
            type="image"
            title="画像アップロード"
            description="HEIC、JPEG、PNG、WebP等の画像ファイルをStorjにアップロードします"
            acceptedTypes={['image']}
            maxFiles={20}
          />
        );
      case 'videos':
        return (
          <UploaderTab
            type="video"
            title="動画アップロード"
            description="MP4、MOV、AVI等の動画ファイルをStorjにアップロードします"
            acceptedTypes={['video']}
            maxFiles={10}
          />
        );
      case 'files':
        return (
          <UploaderTab
            type="file"
            title="ファイルアップロード"
            description="すべてのファイル形式に対応した汎用アップロード機能です"
            acceptedTypes={['image', 'video', 'file']}
            maxFiles={15}
          />
        );
      case 'status':
        return <SystemStatus />;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* ヘッダー */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <h1 className="text-xl font-bold text-gray-900">
                  Storj Uploader
                </h1>
              </div>
            </div>
            <div className="hidden md:block">
              <div className="text-sm text-gray-500">
                ファイルをStorjに安全にアップロード
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* メインコンテンツ */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* タブナビゲーション */}
        <div className="mb-8">
          <nav className="flex space-x-1 bg-white rounded-lg shadow-sm border p-1">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`
                  flex-1 flex items-center justify-center px-3 py-3 text-sm font-medium rounded-md transition-all
                  ${activeTab === tab.id
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                  }
                `}
              >
                <span className="mr-2">{tab.icon}</span>
                <span className="hidden sm:inline">{tab.label}</span>
                <span className="sm:hidden">{tab.label}</span>
              </button>
            ))}
          </nav>

          {/* タブ説明 */}
          <div className="mt-3 text-center">
            <p className="text-sm text-gray-600">
              {tabs.find(tab => tab.id === activeTab)?.description}
            </p>
          </div>
        </div>

        {/* タブコンテンツ */}
        <div className="bg-white rounded-lg shadow-sm border p-6">
          {renderTabContent()}
        </div>
      </main>

      {/* フッター */}
      <footer className="bg-white border-t mt-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="text-center text-sm text-gray-500">
            <p>Storj Uploader Frontend - Powered by React & TypeScript</p>
            <p className="mt-1">
              対応ファイル: 画像 (HEIC/JPEG/PNG等) • 動画 (MP4/MOV/AVI等) • すべてのファイル形式
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default App;