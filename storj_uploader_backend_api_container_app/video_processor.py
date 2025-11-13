#!/usr/bin/env python3
"""
Video processing utilities including thumbnail generation
"""
import os
import subprocess
from pathlib import Path
from typing import Optional, Tuple
import cv2
from PIL import Image
import io

class VideoProcessor:
    """動画処理クラス - サムネイル生成など"""

    # サポートする動画形式
    SUPPORTED_VIDEO_FORMATS = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp', '.flv', '.wmv'}

    # サムネイルのデフォルトサイズ
    DEFAULT_THUMBNAIL_WIDTH = 320
    DEFAULT_THUMBNAIL_HEIGHT = 240

    @staticmethod
    def is_video_file(filename: str) -> bool:
        """ファイルが動画かどうか判定"""
        ext = Path(filename).suffix.lower()
        return ext in VideoProcessor.SUPPORTED_VIDEO_FORMATS

    @staticmethod
    def generate_thumbnail_opencv(
        video_path: str,
        output_path: str,
        width: int = DEFAULT_THUMBNAIL_WIDTH,
        height: int = DEFAULT_THUMBNAIL_HEIGHT,
        frame_position: float = 0.1
    ) -> bool:
        """
        OpenCVを使用して動画からサムネイルを生成

        Args:
            video_path: 動画ファイルのパス
            output_path: サムネイル出力パス
            width: サムネイル幅
            height: サムネイル高さ
            frame_position: 動画の何%の位置からフレームを取得するか (0.0-1.0)

        Returns:
            bool: 成功した場合True
        """
        try:
            # 動画を開く
            video = cv2.VideoCapture(video_path)

            if not video.isOpened():
                print(f"Error: Cannot open video file: {video_path}")
                return False

            # 総フレーム数を取得
            total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
            if total_frames <= 0:
                print(f"Error: Cannot get frame count from video: {video_path}")
                video.release()
                return False

            # 指定位置のフレームに移動
            target_frame = int(total_frames * frame_position)
            video.set(cv2.CAP_PROP_POS_FRAMES, target_frame)

            # フレームを読み込む
            success, frame = video.read()
            video.release()

            if not success or frame is None:
                print(f"Error: Cannot read frame from video: {video_path}")
                return False

            # BGRからRGBに変換（OpenCVはBGR、PILはRGB）
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # PILイメージに変換
            image = Image.fromarray(frame_rgb)

            # リサイズ（アスペクト比を維持）
            image.thumbnail((width, height), Image.Resampling.LANCZOS)

            # 保存
            image.save(output_path, "JPEG", quality=85)

            print(f"✓ Thumbnail generated: {output_path}")
            return True

        except Exception as e:
            print(f"Error generating thumbnail with OpenCV: {e}")
            return False

    @staticmethod
    def generate_thumbnail_ffmpeg(
        video_path: str,
        output_path: str,
        width: int = DEFAULT_THUMBNAIL_WIDTH,
        height: int = DEFAULT_THUMBNAIL_HEIGHT,
        time_position: str = "00:00:01"
    ) -> bool:
        """
        FFmpegを使用して動画からサムネイルを生成

        Args:
            video_path: 動画ファイルのパス
            output_path: サムネイル出力パス
            width: サムネイル幅
            height: サムネイル高さ
            time_position: サムネイル取得位置（形式: HH:MM:SS）

        Returns:
            bool: 成功した場合True
        """
        try:
            # FFmpegコマンドを実行
            command = [
                'ffmpeg',
                '-i', video_path,
                '-ss', time_position,
                '-vframes', '1',
                '-vf', f'scale={width}:{height}:force_original_aspect_ratio=decrease',
                '-y',
                output_path
            ]

            result = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=30
            )

            if result.returncode == 0 and os.path.exists(output_path):
                print(f"✓ Thumbnail generated with FFmpeg: {output_path}")
                return True
            else:
                print(f"Error: FFmpeg failed with return code {result.returncode}")
                print(f"stderr: {result.stderr.decode()}")
                return False

        except subprocess.TimeoutExpired:
            print(f"Error: FFmpeg timeout for video: {video_path}")
            return False
        except FileNotFoundError:
            print("Error: FFmpeg not found. Please install FFmpeg.")
            return False
        except Exception as e:
            print(f"Error generating thumbnail with FFmpeg: {e}")
            return False

    @staticmethod
    def generate_thumbnail(
        video_path: str,
        output_path: str,
        width: int = DEFAULT_THUMBNAIL_WIDTH,
        height: int = DEFAULT_THUMBNAIL_HEIGHT,
        method: str = "opencv"
    ) -> bool:
        """
        動画からサムネイルを生成（メソッド自動選択）

        Args:
            video_path: 動画ファイルのパス
            output_path: サムネイル出力パス
            width: サムネイル幅
            height: サムネイル高さ
            method: 使用するメソッド ("opencv" or "ffmpeg")

        Returns:
            bool: 成功した場合True
        """
        if not os.path.exists(video_path):
            print(f"Error: Video file not found: {video_path}")
            return False

        # メソッドに応じて処理を分岐
        if method == "ffmpeg":
            success = VideoProcessor.generate_thumbnail_ffmpeg(
                video_path, output_path, width, height
            )
            # FFmpegで失敗した場合、OpenCVにフォールバック
            if not success:
                print("Falling back to OpenCV...")
                success = VideoProcessor.generate_thumbnail_opencv(
                    video_path, output_path, width, height
                )
        else:
            success = VideoProcessor.generate_thumbnail_opencv(
                video_path, output_path, width, height
            )
            # OpenCVで失敗した場合、FFmpegにフォールバック
            if not success:
                print("Falling back to FFmpeg...")
                success = VideoProcessor.generate_thumbnail_ffmpeg(
                    video_path, output_path, width, height
                )

        return success

    @staticmethod
    def get_video_info(video_path: str) -> Optional[dict]:
        """
        動画の情報を取得

        Returns:
            dict: {
                'duration': 秒数,
                'width': 幅,
                'height': 高さ,
                'fps': フレームレート,
                'frame_count': 総フレーム数
            }
        """
        try:
            video = cv2.VideoCapture(video_path)

            if not video.isOpened():
                return None

            info = {
                'width': int(video.get(cv2.CAP_PROP_FRAME_WIDTH)),
                'height': int(video.get(cv2.CAP_PROP_FRAME_HEIGHT)),
                'fps': video.get(cv2.CAP_PROP_FPS),
                'frame_count': int(video.get(cv2.CAP_PROP_FRAME_COUNT)),
            }

            # 動画の長さを計算（秒）
            if info['fps'] > 0:
                info['duration'] = info['frame_count'] / info['fps']
            else:
                info['duration'] = 0

            video.release()
            return info

        except Exception as e:
            print(f"Error getting video info: {e}")
            return None
