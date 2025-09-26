#!/usr/bin/env python3
import os
import sys
import shutil
import re
import hashlib
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

class FileOrganizer:
    def __init__(self):
        # Load environment variables from different possible locations
        env_paths = [
            Path('/app/.env'),  # Docker container path
            Path('../storj_container_app/.env'),  # Local development path
            Path('.env')  # Current directory
        ]

        for env_path in env_paths:
            if env_path.exists():
                load_dotenv(env_path)
                break
        else:
            load_dotenv()  # Load from environment if no file found

        # Set up directories
        self.source_dir = Path('/app/source_files')  # Files to organize (mounted volume)
        self.organized_dir = Path('/app/organized_files')  # Output directory (mounted volume)

        # Hash configuration (same as storj_container_app)
        self.hash_length = int(os.getenv('HASH_LENGTH', '10'))

        # Create directories
        self.source_dir.mkdir(exist_ok=True)
        self.organized_dir.mkdir(exist_ok=True)

        print(f"File organizer initialized")
        print(f"Source directory: {self.source_dir.absolute()}")
        print(f"Organized directory: {self.organized_dir.absolute()}")
        print(f"Hash length: {self.hash_length} characters")

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

    def calculate_file_hash(self, file_path):
        """Calculate MD5 hash of a file and return first N characters (same as storj_container_app)."""
        hash_md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()[:self.hash_length]

    def generate_filename_with_hash(self, file_path):
        """Generate filename with hash suffix (same format as storj_container_app)"""
        file_hash = self.calculate_file_hash(file_path)
        name_parts = file_path.name.rsplit('.', 1)

        if len(name_parts) == 2:
            base_name, extension = name_parts
            new_name = f"{base_name}_{file_hash}.{extension}"
        else:
            new_name = f"{file_path.name}_{file_hash}"

        return new_name

    def organize_file(self, file_path):
        """Organize a single file into YYYYMM folder structure with hash suffix"""
        try:
            # Get file date and format as YYYYMM
            file_date = self.get_file_date(file_path)
            month_folder = file_date.strftime("%Y%m")

            # Create target directory
            target_dir = self.organized_dir / month_folder
            target_dir.mkdir(exist_ok=True)

            # Generate filename with hash (same as storj_container_app)
            hashed_filename = self.generate_filename_with_hash(file_path)
            target_file = target_dir / hashed_filename

            # Handle duplicate filenames (unlikely with hash, but just in case)
            counter = 1
            original_target = target_file
            while target_file.exists():
                name_parts = original_target.name.rsplit('.', 1)
                if len(name_parts) == 2:
                    base_name, extension = name_parts
                    # Add timestamp to make it unique
                    current_time = datetime.now().strftime("%Y%m%d%H%M%S")
                    target_file = target_dir / f"{base_name}_{current_time}.{extension}"
                else:
                    current_time = datetime.now().strftime("%Y%m%d%H%M%S")
                    target_file = target_dir / f"{original_target.name}_{current_time}"
                break  # With hash, duplicates are very unlikely, so just add timestamp once

            # Move file
            shutil.move(str(file_path), str(target_file))

            print(f"Moved {file_path.name} to {month_folder}/{hashed_filename} (date: {file_date.strftime('%Y-%m-%d %H:%M:%S')})")
            return True, month_folder, file_date

        except Exception as e:
            print(f"Error organizing {file_path.name}: {e}")
            return False, None, None

    def organize_files(self):
        """Organize all files in source directory"""
        if not self.source_dir.exists() or not any(self.source_dir.iterdir()):
            print("No files found in source directory.")
            return True

        # Get all files to organize
        files_to_organize = [f for f in self.source_dir.iterdir() if f.is_file()]

        if not files_to_organize:
            print("No files found in source directory.")
            return True

        print(f"Starting organization of {len(files_to_organize)} files...")

        organized_count = 0
        failed_files = []
        folder_stats = {}

        for file_path in files_to_organize:
            success, month_folder, file_date = self.organize_file(file_path)

            if success:
                organized_count += 1
                if month_folder not in folder_stats:
                    folder_stats[month_folder] = 0
                folder_stats[month_folder] += 1
            else:
                failed_files.append(file_path.name)

        # Report results
        print(f"\nOrganization completed:")
        print(f"  Successfully organized: {organized_count}")
        print(f"  Failed: {len(failed_files)}")

        if folder_stats:
            print(f"\nFiles organized by month:")
            for month, count in sorted(folder_stats.items()):
                print(f"  {month}: {count} files")

        if failed_files:
            print("Failed files:")
            for filename in failed_files:
                print(f"  - {filename}")
            return False

        return True

    def compare_with_storj_structure(self):
        """Compare local organized structure with Storj virtual structure"""
        # Path to virtual files from storj_mount_drive (mounted in Docker)
        virtual_files_path = Path('/app/virtual_files')

        print(f"Checking virtual files at: {virtual_files_path}")
        try:
            # List contents to verify access
            vf_contents = list(virtual_files_path.iterdir())
            print(f"Found {len(vf_contents)} directories in virtual_files")
        except Exception as e:
            print(f"Error accessing virtual files: {e}")
            return False

        print("\nComparing local structure with Storj structure...")

        # Get local folders
        local_folders = set()
        local_files = {}

        for item in self.organized_dir.iterdir():
            if item.is_dir():
                local_folders.add(item.name)
                local_files[item.name] = set(f.name for f in item.iterdir() if f.is_file())

        # Get Storj virtual folders
        storj_folders = set()
        storj_files = {}

        for item in virtual_files_path.iterdir():
            if item.is_dir():
                storj_folders.add(item.name)
                storj_files[item.name] = set(f.name for f in item.iterdir() if f.is_file())

        # Compare folders
        common_folders = local_folders & storj_folders
        local_only_folders = local_folders - storj_folders
        storj_only_folders = storj_folders - local_folders

        print(f"\nFolder comparison:")
        print(f"  Common folders: {len(common_folders)}")
        print(f"  Local only: {len(local_only_folders)}")
        print(f"  Storj only: {len(storj_only_folders)}")

        if local_only_folders:
            print(f"  Local only folders: {sorted(local_only_folders)}")
        if storj_only_folders:
            print(f"  Storj only folders: {sorted(storj_only_folders)}")

        # Compare files in common folders
        total_matches = 0
        total_local_only = 0
        total_storj_only = 0

        for folder in sorted(common_folders):
            local_folder_files = local_files.get(folder, set())
            storj_folder_files = storj_files.get(folder, set())

            matches = local_folder_files & storj_folder_files
            local_only = local_folder_files - storj_folder_files
            storj_only = storj_folder_files - local_only

            total_matches += len(matches)
            total_local_only += len(local_only)
            total_storj_only += len(storj_only)

            print(f"\n  {folder}/:")
            print(f"    Matching files: {len(matches)}")
            print(f"    Local only: {len(local_only)}")
            print(f"    Storj only: {len(storj_only)}")

            if local_only and len(local_only) <= 5:  # Show max 5 examples
                print(f"    Local only files: {list(local_only)[:5]}")
            if storj_only and len(storj_only) <= 5:  # Show max 5 examples
                print(f"    Storj only files: {list(storj_only)[:5]}")

        print(f"\nOverall file comparison:")
        print(f"  Total matching files: {total_matches}")
        print(f"  Total local only files: {total_local_only}")
        print(f"  Total Storj only files: {total_storj_only}")

        # Calculate match percentage
        total_expected = total_matches + total_local_only + total_storj_only
        if total_expected > 0:
            match_percentage = (total_matches / total_expected) * 100
            print(f"  Match percentage: {match_percentage:.1f}%")

        return True

    def show_status(self):
        """Show current status of file organization"""
        print(f"File Organizer Status:")
        print(f"  Source directory: {self.source_dir.absolute()}")
        print(f"  Organized directory: {self.organized_dir.absolute()}")

        # Count source files
        if self.source_dir.exists():
            source_files = len([f for f in self.source_dir.iterdir() if f.is_file()])
            print(f"  Files to organize: {source_files}")
        else:
            print(f"  Source directory: Not found")

        # Count organized files
        if self.organized_dir.exists():
            organized_folders = [d for d in self.organized_dir.iterdir() if d.is_dir()]
            total_organized = 0
            for folder in organized_folders:
                file_count = len([f for f in folder.iterdir() if f.is_file()])
                total_organized += file_count
                print(f"    {folder.name}/: {file_count} files")
            print(f"  Total organized files: {total_organized}")
        else:
            print(f"  Organized directory: Not found")

def main():
    if len(sys.argv) < 2:
        print("Usage: python file_organizer.py <command>")
        print("Commands:")
        print("  organize  - Organize files by date into YYYYMM folders")
        print("  compare   - Compare local structure with Storj structure")
        print("  status    - Show current status")
        return

    command = sys.argv[1].lower()
    organizer = FileOrganizer()

    if command == 'organize':
        organizer.organize_files()
    elif command == 'compare':
        organizer.compare_with_storj_structure()
    elif command == 'status':
        organizer.show_status()
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()