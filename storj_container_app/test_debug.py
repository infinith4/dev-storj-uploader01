#!/usr/bin/env python3
import os
import sys
import hashlib
import re
from datetime import datetime
from pathlib import Path

class DebugStorjUploader:
    def __init__(self):
        self.bucket_name = 'test-bucket'
        self.remote_name = 'storj'
        self.hash_length = 10
        self.upload_target_dir = Path('upload_target')
        self.uploaded_dir = Path('uploaded')

    def calculate_file_hash(self, file_path):
        """Calculate MD5 hash of a file and return first N characters."""
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()[:self.hash_length]

    def debug_upload_files(self):
        if not self.upload_target_dir.exists() or not any(self.upload_target_dir.iterdir()):
            print("No files found in upload_target directory.")
            return

        for file_path in self.upload_target_dir.iterdir():
            if file_path.is_file():
                # Get file creation time and format as YYYYMM
                file_ctime = datetime.fromtimestamp(file_path.stat().st_ctime)
                file_month = file_ctime.strftime("%Y%m")
                remote_path = f"{self.remote_name}:{self.bucket_name}/{file_month}/"

                # Calculate hash
                file_hash = self.calculate_file_hash(file_path)

                print(f"File: {file_path.name}")
                print(f"  Creation time: {file_ctime}")
                print(f"  Month folder: {file_month}")
                print(f"  Remote path: {remote_path}")
                print(f"  File hash: {file_hash}")
                print(f"  New filename: {file_path.stem}_{file_hash}{file_path.suffix}")
                print("---")

if __name__ == "__main__":
    uploader = DebugStorjUploader()
    uploader.debug_upload_files()