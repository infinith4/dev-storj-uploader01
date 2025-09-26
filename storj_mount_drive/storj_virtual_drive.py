#!/usr/bin/env python3
import os
import sys
import subprocess
import json
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

class StorjVirtualDrive:
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

        self.bucket_name = os.getenv('STORJ_BUCKET_NAME', 'default-bucket')
        self.remote_name = os.getenv('STORJ_REMOTE_NAME', 'storj')
        self.virtual_drive_root = Path('virtual_files')

        # Check for rclone config in different locations
        config_paths = [
            Path('/app/config/rclone.conf'),  # Docker container path
            Path('../storj_container_app/rclone.conf'),  # Local development path
            Path('rclone.conf')  # Current directory
        ]

        self.rclone_config_path = None
        for config_path in config_paths:
            if config_path.exists():
                self.rclone_config_path = config_path
                break

        # Create virtual drive root directory
        self.virtual_drive_root.mkdir(exist_ok=True)

        print(f"Virtual drive initialized for bucket: {self.bucket_name}")
        print(f"Virtual files will be created in: {self.virtual_drive_root.absolute()}")

    def run_rclone_command(self, command):
        """Run rclone command with proper config file"""
        try:
            # Add config file parameter if it exists
            if self.rclone_config_path.exists():
                command = f"rclone --config {self.rclone_config_path} {command}"
            else:
                command = f"rclone {command}"

            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            return True, result.stdout
        except subprocess.CalledProcessError as e:
            return False, e.stderr

    def get_bucket_structure(self):
        """Get complete file structure from Storj bucket"""
        print(f"Fetching bucket structure from {self.remote_name}:{self.bucket_name}...")

        # Use rclone lsjson to get detailed file information
        command = f"lsjson -R {self.remote_name}:{self.bucket_name}/"
        success, output = self.run_rclone_command(command)

        if not success:
            print(f"Error getting bucket structure: {output}")
            return None

        try:
            files = json.loads(output) if output.strip() else []
            print(f"Found {len(files)} files in bucket")
            return files
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON output: {e}")
            return None

    def create_virtual_file(self, file_info):
        """Create a virtual file (empty file with correct name and metadata)"""
        file_path = file_info['Path']
        file_size = file_info['Size']
        mod_time = file_info.get('ModTime', '')

        # Create full path in virtual drive
        virtual_file_path = self.virtual_drive_root / file_path

        # Create parent directories if they don't exist
        virtual_file_path.parent.mkdir(parents=True, exist_ok=True)

        # Create empty file (or file with size indicator)
        with open(virtual_file_path, 'w') as f:
            f.write(f"# Virtual file placeholder\n")
            f.write(f"# Original file: {file_path}\n")
            f.write(f"# Size: {file_size} bytes\n")
            f.write(f"# Modified: {mod_time}\n")
            f.write(f"# Bucket: {self.bucket_name}\n")
            f.write(f"# Remote: {self.remote_name}:{self.bucket_name}/{file_path}\n")

        # Set file modification time if available
        if mod_time:
            try:
                mod_datetime = datetime.fromisoformat(mod_time.replace('Z', '+00:00'))
                mod_timestamp = mod_datetime.timestamp()
                os.utime(virtual_file_path, (mod_timestamp, mod_timestamp))
            except:
                pass  # Ignore if timestamp parsing fails

        return virtual_file_path

    def create_virtual_structure(self):
        """Create complete virtual file structure"""
        files = self.get_bucket_structure()

        if files is None:
            return False

        created_files = 0
        created_dirs = set()

        print(f"Creating virtual file structure...")

        for file_info in files:
            if file_info['IsDir']:
                # It's a directory
                dir_path = self.virtual_drive_root / file_info['Path']
                dir_path.mkdir(parents=True, exist_ok=True)
                created_dirs.add(file_info['Path'])
                print(f"Created directory: {file_info['Path']}")
            else:
                # It's a file
                virtual_file = self.create_virtual_file(file_info)
                created_files += 1
                print(f"Created virtual file: {file_info['Path']} ({file_info['Size']} bytes)")

        print(f"\nVirtual drive creation completed:")
        print(f"  Directories created: {len(created_dirs)}")
        print(f"  Virtual files created: {created_files}")
        print(f"  Location: {self.virtual_drive_root.absolute()}")

        return True

    def sync_virtual_drive(self):
        """Synchronize virtual drive with current bucket state"""
        print("Synchronizing virtual drive with Storj bucket...")

        # Remove existing virtual structure content (but not the mounted directory itself)
        if self.virtual_drive_root.exists():
            import shutil
            import os

            # Remove only the contents, not the directory itself to avoid Docker volume issues
            for item in self.virtual_drive_root.iterdir():
                if item.is_dir():
                    shutil.rmtree(item)
                else:
                    item.unlink()
            print("Removed existing virtual structure content")

        # Ensure virtual structure directory exists
        self.virtual_drive_root.mkdir(exist_ok=True)
        return self.create_virtual_structure()

    def list_virtual_files(self):
        """List all virtual files with their metadata"""
        if not self.virtual_drive_root.exists():
            print("No virtual drive found. Run sync first.")
            return

        print(f"Virtual files in {self.virtual_drive_root}:")
        for file_path in self.virtual_drive_root.rglob('*'):
            if file_path.is_file():
                rel_path = file_path.relative_to(self.virtual_drive_root)
                file_size = file_path.stat().st_size
                mod_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                print(f"  {rel_path} ({file_size} bytes, modified: {mod_time.strftime('%Y-%m-%d %H:%M:%S')})")

    def show_status(self):
        """Show current status of virtual drive"""
        print(f"Storj Virtual Drive Status:")
        print(f"  Bucket: {self.bucket_name}")
        print(f"  Remote: {self.remote_name}")
        print(f"  Virtual drive location: {self.virtual_drive_root.absolute()}")

        if self.virtual_drive_root.exists():
            file_count = len([f for f in self.virtual_drive_root.rglob('*') if f.is_file()])
            dir_count = len([d for d in self.virtual_drive_root.rglob('*') if d.is_dir()])
            print(f"  Virtual files: {file_count}")
            print(f"  Virtual directories: {dir_count}")
        else:
            print("  Virtual drive: Not created")

def main():
    if len(sys.argv) < 2:
        print("Usage: python storj_virtual_drive.py <command>")
        print("Commands:")
        print("  sync    - Synchronize virtual drive with Storj bucket")
        print("  status  - Show virtual drive status")
        print("  list    - List all virtual files")
        return

    command = sys.argv[1].lower()
    drive = StorjVirtualDrive()

    if command == 'sync':
        drive.sync_virtual_drive()
    elif command == 'status':
        drive.show_status()
    elif command == 'list':
        drive.list_virtual_files()
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()