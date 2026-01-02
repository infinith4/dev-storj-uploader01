#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import hashlib
import re
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
from PIL import Image
import io

# Blob Storage support
try:
    from azure.storage.blob import BlobServiceClient
    BLOB_STORAGE_AVAILABLE = True
except ImportError:
    BLOB_STORAGE_AVAILABLE = False
    print("Warning: azure-storage-blob not installed. Blob Storage functions will not be available.")

class StorjUploader:
    def __init__(self):
        load_dotenv()

        # Check rclone configuration
        rclone_config_path = Path.home() / '.config' / 'rclone' / 'rclone.conf'
        if rclone_config_path.exists():
            print(f"✓ rclone.conf found at: {rclone_config_path}")
            print(f"  File size: {rclone_config_path.stat().st_size} bytes")
            # Remove RCLONE_CONFIG env var if it contains content (not a path)
            if 'RCLONE_CONFIG' in os.environ:
                rclone_config_value = os.getenv('RCLONE_CONFIG', '')
                if '\n' in rclone_config_value or '[' in rclone_config_value:
                    print("  Removing RCLONE_CONFIG env var (contains config content, not path)")
                    os.environ.pop('RCLONE_CONFIG', None)
                    print("  ✓ RCLONE_CONFIG env var removed, rclone will use default path")
        else:
            print(f"✗ WARNING: rclone.conf NOT found at: {rclone_config_path}")
            print(f"  RCLONE_CONFIG env var set: {'Yes' if os.getenv('RCLONE_CONFIG') else 'No'}")

        self.bucket_name = os.getenv('STORJ_BUCKET_NAME', 'default-bucket')
        self.remote_name = os.getenv('STORJ_REMOTE_NAME', 'storj')
        self.hash_length = int(os.getenv('HASH_LENGTH', '10'))
        self.max_workers = int(os.getenv('MAX_WORKERS', '8'))
        self.rclone_multi_thread_streams = int(os.getenv('RCLONE_MULTI_THREAD_STREAMS', '4'))
        self.rclone_multi_thread_cutoff = os.getenv('RCLONE_MULTI_THREAD_CUTOFF', '32M').strip()
        self.rclone_copy_flags = self._build_rclone_copy_flags()
        self.upload_target_dir = Path('upload_target')
        self.uploaded_dir = Path('uploaded')
        self.temp_dir = Path('temp_upload')
        self.lock = threading.Lock()

        # Blob Storage configuration
        self.blob_service_client = None
        self.use_blob_storage = False
        self.upload_container_name = os.getenv('AZURE_STORAGE_UPLOAD_CONTAINER', 'upload-target')
        self.uploaded_container_name = os.getenv('AZURE_STORAGE_UPLOADED_CONTAINER', 'uploaded')
        self.blob_download_concurrency = int(os.getenv('AZURE_BLOB_DOWNLOAD_CONCURRENCY', '4'))

        # Try to initialize Blob Storage
        if BLOB_STORAGE_AVAILABLE:
            account_name = os.getenv('AZURE_STORAGE_ACCOUNT_NAME')
            account_key = os.getenv('AZURE_STORAGE_ACCOUNT_KEY')

            if account_name and account_key:
                try:
                    self.blob_service_client = BlobServiceClient(
                        account_url=f"https://{account_name}.blob.core.windows.net",
                        credential=account_key
                    )
                    self.use_blob_storage = True
                    print("✓ Blob Storage initialized successfully")
                except Exception as e:
                    print(f"⚠ Failed to initialize Blob Storage: {e}")
                    print("  Files will be read from local filesystem instead")

        # Create local directories (used as fallback or temp storage)
        self.uploaded_dir.mkdir(exist_ok=True)
        self.upload_target_dir.mkdir(exist_ok=True)
        self.temp_dir.mkdir(exist_ok=True)

    def run_rclone_command(self, command):
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            return True, result.stdout
        except subprocess.CalledProcessError as e:
            return False, e.stderr

    def _build_rclone_copy_flags(self):
        flags = []
        if self.rclone_multi_thread_streams > 1:
            flags.append(f"--multi-thread-streams {self.rclone_multi_thread_streams}")
            if self.rclone_multi_thread_cutoff:
                flags.append(f"--multi-thread-cutoff {self.rclone_multi_thread_cutoff}")
        if not flags:
            return ""
        return " " + " ".join(flags)

    def check_bucket_exists(self):
        command = f"rclone lsd {self.remote_name}:"
        success, output = self.run_rclone_command(command)
        if not success:
            print(f"Error checking buckets: {output}")
            return False

        buckets = [line.strip().split()[-1] for line in output.strip().split('\n') if line.strip()]
        return self.bucket_name in buckets

    def create_bucket(self):
        if self.check_bucket_exists():
            print(f"Bucket '{self.bucket_name}' already exists.")
            return True

        print(f"Creating bucket '{self.bucket_name}'...")
        command = f"rclone mkdir {self.remote_name}:{self.bucket_name}"
        success, output = self.run_rclone_command(command)

        if success:
            print(f"Bucket '{self.bucket_name}' created successfully.")
            return True
        else:
            print(f"Error creating bucket: {output}")
            return False

    def calculate_file_hash(self, file_path):
        """Calculate MD5 hash of a file and return first N characters."""
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()[:self.hash_length]

    def parse_filename_with_hash(self, filename):
        """
        Parse filename to extract base name, hash, timestamp, and extension.
        Returns: (base_name, hash_part, timestamp, extension)
        """
        name_parts = filename.rsplit('.', 1)
        if len(name_parts) == 2:
            name_without_ext, extension = name_parts
        else:
            name_without_ext = filename
            extension = ""

        # Pattern: basename_hash_timestamp or basename_hash
        pattern = rf'(.+)_([a-f0-9]{{{self.hash_length}}})(?:_(\d{{14}}))?$'
        match = re.match(pattern, name_without_ext)

        if match:
            base_name = match.group(1)
            hash_part = match.group(2)
            timestamp = match.group(3) if match.group(3) else None
            return base_name, hash_part, timestamp, extension
        else:
            return name_without_ext, None, None, extension

    def check_duplicate_by_hash_and_name(self, file_path, existing_files):
        """
        Check if file with same name and hash already exists.
        Returns: (should_skip, reason)
        """
        file_hash = self.calculate_file_hash(file_path)
        original_name = file_path.name

        # Parse original filename
        base_name, _, _, extension = self.parse_filename_with_hash(original_name)

        for existing_file in existing_files:
            existing_base, existing_hash, _, existing_ext = self.parse_filename_with_hash(existing_file)

            # Check if same base name and hash
            if (base_name == existing_base and
                existing_hash == file_hash and
                extension == existing_ext):
                return True, f"File with same name and hash already exists: {existing_file}"

        return False, ""

    def get_unique_filename(self, file_path, remote_path):
        """
        Check if file exists in remote and generate unique filename with hash+suffix if needed.
        Returns: (unique_filename, needs_suffix, should_skip, skip_reason)
        """
        command = f"rclone ls {remote_path}"
        success, output = self.run_rclone_command(command)

        if not success:
            # If we can't list files, assume no conflict
            file_hash = self.calculate_file_hash(file_path)
            name_parts = file_path.name.rsplit('.', 1)
            if len(name_parts) == 2:
                base_name, extension = name_parts
                new_name = f"{base_name}_{file_hash}.{extension}"
            else:
                new_name = f"{file_path.name}_{file_hash}"
            return new_name, True, False, ""

        existing_files = []
        if output.strip():
            for line in output.strip().split('\n'):
                if line.strip():
                    # rclone ls output format: "size filename"
                    parts = line.strip().split(None, 1)
                    if len(parts) >= 2:
                        existing_files.append(parts[1])

        # Check for duplicate by hash and name
        should_skip, skip_reason = self.check_duplicate_by_hash_and_name(file_path, existing_files)
        if should_skip:
            return "", False, True, skip_reason

        # Calculate file hash
        file_hash = self.calculate_file_hash(file_path)

        # Parse original filename
        name_parts = file_path.name.rsplit('.', 1)
        if len(name_parts) == 2:
            base_name, extension = name_parts
        else:
            base_name = file_path.name
            extension = ""

        # Generate filename with hash
        if extension:
            base_with_hash = f"{base_name}_{file_hash}.{extension}"
        else:
            base_with_hash = f"{base_name}_{file_hash}"

        # Check if base filename with hash exists
        if base_with_hash not in existing_files:
            return base_with_hash, True, False, ""

        # If exists, add timestamp
        current_time = datetime.now().strftime("%Y%m%d%H%M%S")
        if extension:
            new_name = f"{base_name}_{file_hash}_{current_time}.{extension}"
        else:
            new_name = f"{base_name}_{file_hash}_{current_time}"

        return new_name, True, False, ""

    def extract_date_from_filename(self, filename):
        """
        Extract date from filename patterns like YYYY-MM-DD_HH-MM-SS_XXX.ext
        Returns datetime object or None if not found
        """
        # Pattern: YYYY-MM-DD_HH-MM-SS
        pattern = r'(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})'
        match = re.search(pattern, filename)

        if match:
            year, month, day, hour, minute, second = map(int, match.groups())
            try:
                return datetime(year, month, day, hour, minute, second)
            except ValueError:
                return None
        return None

    def get_file_date(self, file_path):
        """
        Get file date from filename first, fallback to file system date
        Uses the older date between creation time and modification time
        Returns datetime object
        """
        # Try to extract date from filename first
        filename_date = self.extract_date_from_filename(file_path.name)
        if filename_date:
            return filename_date

        # Fallback to file system date: use the older of creation time and modification time
        stat = file_path.stat()
        creation_time = datetime.fromtimestamp(stat.st_ctime)
        modification_time = datetime.fromtimestamp(stat.st_mtime)

        # Return the older date
        return min(creation_time, modification_time)

    def _is_temp_hash_file(self, filename):
        """
        Check if filename appears to be a temporary hash file that should be ignored
        """
        # Pattern: filename with hash at the end (e.g., "filename_abcd1234.ext")
        pattern = rf'.*_[a-f0-9]{{{self.hash_length}}}(\.|$)'
        return bool(re.search(pattern, filename))

    def _is_image_file(self, file_path):
        """
        Check if file is an image based on extension
        """
        image_extensions = {'.jpg', '.jpeg', '.png', '.heic', '.webp', '.bmp', '.tiff', '.gif'}
        return file_path.suffix.lower() in image_extensions

    def _is_video_thumbnail(self, filename):
        """
        Check if file is a video thumbnail based on naming convention
        Video thumbnails are named: {video_stem}_thumb.jpg
        """
        return filename.lower().endswith('_thumb.jpg')

    def generate_thumbnail(self, file_path, size=(300, 300)):
        """
        Generate thumbnail for image file
        Returns: (success: bool, thumbnail_bytes: bytes, error_msg: str)
        """
        try:
            # Open image
            with Image.open(file_path) as img:
                # Convert RGBA/LA/P to RGB for JPEG
                if img.mode in ('RGBA', 'LA', 'P'):
                    img = img.convert('RGB')

                # Generate thumbnail (maintain aspect ratio)
                img.thumbnail(size, Image.Resampling.LANCZOS)

                # Save as JPEG
                output = io.BytesIO()
                img.save(output, format='JPEG', quality=85, optimize=True)
                thumbnail_data = output.getvalue()

                return True, thumbnail_data, ""
        except Exception as e:
            return False, b"", str(e)

    def upload_single_file(self, file_path):
        """Upload a single file and return result"""
        thread_id = threading.current_thread().name
        try:
            # Get file date (from filename or file system) and format as YYYYMM
            file_date = self.get_file_date(file_path)
            file_month = file_date.strftime("%Y%m")

            # Video thumbnails go to thumbnails/YYYYMM/ directory
            if self._is_video_thumbnail(file_path.name):
                remote_path = f"{self.remote_name}:{self.bucket_name}/thumbnails/{file_month}/"
            else:
                remote_path = f"{self.remote_name}:{self.bucket_name}/{file_month}/"

            with self.lock:
                print(f"[{thread_id}] Uploading {file_path.name} to {remote_path}... (date: {file_date.strftime('%Y-%m-%d')})")

            # Get unique filename and check for duplicates
            unique_filename, has_suffix, should_skip, skip_reason = self.get_unique_filename(file_path, remote_path)

            if should_skip:
                with self.lock:
                    print(f"[{thread_id}] Skipping '{file_path.name}': {skip_reason}")
                    # Move skipped file to uploaded directory
                    destination = self.uploaded_dir / file_path.name
                    shutil.move(str(file_path), str(destination))
                    print(f"[{thread_id}] Moved {file_path.name} to uploaded directory (skipped).")
                return True, file_path, "skipped"

            if has_suffix:
                with self.lock:
                    print(f"[{thread_id}] File '{file_path.name}' will be uploaded as '{unique_filename}'.")

            # Upload with potentially renamed file
            if has_suffix:
                # Create thread-specific temporary directory
                thread_temp_dir = self.temp_dir / thread_id
                thread_temp_dir.mkdir(exist_ok=True)

                # Create temporary file with new name in thread-specific directory
                temp_file = thread_temp_dir / unique_filename
                try:
                    shutil.copy2(file_path, temp_file)
                    command = f"rclone copy '{temp_file}' {remote_path}{self.rclone_copy_flags}"
                    success, output = self.run_rclone_command(command)
                finally:
                    # Ensure temporary file is always cleaned up
                    if temp_file.exists():
                        temp_file.unlink()
                    # Clean up empty thread directory if possible
                    try:
                        thread_temp_dir.rmdir()
                    except OSError:
                        # Directory not empty or other issue, ignore
                        pass
            else:
                command = f"rclone copy '{file_path}' {remote_path}{self.rclone_copy_flags}"
                success, output = self.run_rclone_command(command)

            if success:
                with self.lock:
                    print(f"[{thread_id}] Successfully uploaded: {unique_filename}")

                # Generate and upload thumbnail if image file
                if self._is_image_file(file_path):
                    thumbnail_success, thumbnail_data, thumb_error = self.generate_thumbnail(file_path)
                    if thumbnail_success:
                        # Upload thumbnail to thumbnails/ directory
                        thumbnail_remote_path = f"{self.remote_name}:{self.bucket_name}/thumbnails/{file_month}/"

                        # Create thread-specific temporary directory for thumbnail
                        thread_temp_dir = self.temp_dir / thread_id
                        thread_temp_dir.mkdir(exist_ok=True)

                        # Change extension to .jpg for thumbnail
                        thumb_filename = unique_filename.rsplit('.', 1)[0] + '.jpg'
                        temp_thumb_file = thread_temp_dir / thumb_filename

                        try:
                            # Write thumbnail data to temp file
                            with open(temp_thumb_file, 'wb') as f:
                                f.write(thumbnail_data)

                            # Upload thumbnail
                            thumb_command = f"rclone copy '{temp_thumb_file}' {thumbnail_remote_path}{self.rclone_copy_flags}"
                            thumb_success, thumb_output = self.run_rclone_command(thumb_command)

                            if thumb_success:
                                with self.lock:
                                    print(f"[{thread_id}] Successfully uploaded thumbnail: {thumb_filename}")
                            else:
                                with self.lock:
                                    print(f"[{thread_id}] Warning: Failed to upload thumbnail: {thumb_output}")
                        finally:
                            # Clean up temp thumbnail file
                            if temp_thumb_file.exists():
                                temp_thumb_file.unlink()
                            try:
                                thread_temp_dir.rmdir()
                            except OSError:
                                pass
                    else:
                        with self.lock:
                            print(f"[{thread_id}] Warning: Failed to generate thumbnail: {thumb_error}")

                # Move file to uploaded directory after successful upload
                with self.lock:
                    try:
                        destination = self.uploaded_dir / file_path.name
                        shutil.move(str(file_path), str(destination))
                        print(f"[{thread_id}] Moved {file_path.name} to uploaded directory.")
                    except Exception as e:
                        print(f"[{thread_id}] Error moving {file_path.name}: {e}")

                return True, file_path, "uploaded"
            else:
                with self.lock:
                    print(f"[{thread_id}] Error uploading {file_path.name}: {output}")
                return False, file_path, f"error: {output}"

        except Exception as e:
            with self.lock:
                print(f"[{thread_id}] Exception uploading {file_path.name}: {e}")
            return False, file_path, f"exception: {e}"

    def upload_single_file_from_blob(self, blob_name):
        """Download blob, upload to Storj, then move to uploaded container"""
        thread_id = threading.current_thread().name

        try:
            # Download blob to temporary directory
            with self.lock:
                print(f"[{thread_id}] Downloading blob: {blob_name}")

            local_file_path = self.download_blob_to_temp(blob_name, thread_id)
            if not local_file_path:
                with self.lock:
                    print(f"[{thread_id}] Failed to download blob: {blob_name}")
                return False, blob_name, "download_failed"

            # Upload to Storj using existing method
            success, _, status = self.upload_single_file(local_file_path)

            # Clean up temporary file
            if local_file_path.exists():
                local_file_path.unlink()

            # Clean up thread directory if empty
            thread_temp_dir = self.temp_dir / thread_id
            try:
                thread_temp_dir.rmdir()
            except OSError:
                pass

            if success:
                # Move blob to uploaded container
                if self.move_blob_to_uploaded(blob_name):
                    with self.lock:
                        print(f"[{thread_id}] Moved blob {blob_name} to uploaded container")
                else:
                    with self.lock:
                        print(f"[{thread_id}] Warning: Failed to move blob {blob_name} to uploaded container")

            return success, blob_name, status

        except Exception as e:
            with self.lock:
                print(f"[{thread_id}] Exception processing blob {blob_name}: {e}")
            return False, blob_name, f"exception: {e}"

    def list_blob_files(self):
        """List all blob files in upload-target container"""
        if not self.use_blob_storage:
            return []

        try:
            container_client = self.blob_service_client.get_container_client(self.upload_container_name)
            blob_names = [blob.name for blob in container_client.list_blobs()]
            return blob_names
        except Exception as e:
            print(f"Error listing blob files: {e}")
            return []

    def download_blob_to_temp(self, blob_name, thread_id):
        """Download a blob to temporary directory for processing"""
        if not self.use_blob_storage:
            return None

        try:
            # Create thread-specific temp directory
            thread_temp_dir = self.temp_dir / thread_id
            thread_temp_dir.mkdir(exist_ok=True)

            # Download blob
            local_path = thread_temp_dir / blob_name
            blob_client = self.blob_service_client.get_blob_client(
                container=self.upload_container_name,
                blob=blob_name
            )

            with open(local_path, "wb") as download_file:
                downloader = blob_client.download_blob(max_concurrency=self.blob_download_concurrency)
                download_file.write(downloader.readall())

            return local_path
        except Exception as e:
            print(f"Error downloading blob {blob_name}: {e}")
            return None

    def move_blob_to_uploaded(self, blob_name):
        """Move blob from upload-target to uploaded container"""
        if not self.use_blob_storage:
            return False

        try:
            # Copy to uploaded container
            source_blob = self.blob_service_client.get_blob_client(self.upload_container_name, blob_name)
            dest_blob = self.blob_service_client.get_blob_client(self.uploaded_container_name, blob_name)

            dest_blob.start_copy_from_url(source_blob.url)

            # Delete from source
            source_blob.delete_blob()

            return True
        except Exception as e:
            print(f"Error moving blob {blob_name}: {e}")
            return False

    def upload_files(self):
        # Get files to upload from Blob Storage or local filesystem
        if self.use_blob_storage:
            blob_names = self.list_blob_files()
            if not blob_names:
                print("No files found in Blob Storage upload-target container.")
                return True

            # Filter out temporary hash files
            files_to_upload = [name for name in blob_names if not self._is_temp_hash_file(name)]

            if not files_to_upload:
                print("No files found in Blob Storage upload-target container.")
                return True

            print(f"Found {len(files_to_upload)} files in Blob Storage to upload")
        else:
            # Local filesystem mode
            if not self.upload_target_dir.exists() or not any(self.upload_target_dir.iterdir()):
                print("No files found in upload_target directory.")
                return True

            # Get all files to upload (exclude temporary hash files)
            files_to_upload = [f.name for f in self.upload_target_dir.iterdir()
                              if f.is_file() and not self._is_temp_hash_file(f.name)]

            if not files_to_upload:
                print("No files found in upload_target directory.")
                return True

        print(f"Starting upload of {len(files_to_upload)} files with {self.max_workers} workers...")

        uploaded_count = 0
        failed_uploads = []

        # Use ThreadPoolExecutor for parallel uploads
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            # Submit all upload tasks based on storage type
            if self.use_blob_storage:
                # Blob Storage mode: upload from blob names
                future_to_file = {executor.submit(self.upload_single_file_from_blob, blob_name): blob_name
                                 for blob_name in files_to_upload}
            else:
                # Local filesystem mode: upload from file paths
                file_paths = [self.upload_target_dir / filename for filename in files_to_upload]
                future_to_file = {executor.submit(self.upload_single_file, file_path): file_path
                                 for file_path in file_paths}

            # Process completed uploads
            for future in as_completed(future_to_file):
                success, file_identifier, status = future.result()

                if success and status == "uploaded":
                    uploaded_count += 1
                elif not success:
                    failed_uploads.append((file_identifier, status))

        # Report results
        print(f"\nUpload completed:")
        print(f"  Successfully uploaded: {uploaded_count}")
        print(f"  Failed uploads: {len(failed_uploads)}")

        if failed_uploads:
            print("Failed files:")
            for file_identifier, reason in failed_uploads:
                # Handle both Path objects and string blob names
                if isinstance(file_identifier, Path):
                    filename = file_identifier.name
                else:
                    filename = file_identifier
                print(f"  - {filename}: {reason}")
            return False

        return True

    def run(self):
        print("Starting Storj upload process...")

        if not self.create_bucket():
            sys.exit(1)

        if not self.upload_files():
            sys.exit(1)

        print("Upload process completed successfully.")

if __name__ == "__main__":
    uploader = StorjUploader()
    uploader.run()
