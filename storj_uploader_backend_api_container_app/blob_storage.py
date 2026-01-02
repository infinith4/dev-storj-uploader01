"""
Azure Blob Storage helper module.
Local環境とAzure環境の両方でBlob Storageを使用します。
"""
import os
from pathlib import Path
from typing import List, Optional
from azure.storage.blob import BlobServiceClient, BlobClient, ContainerClient

class BlobStorageHelper:
    """Helper class for Azure Blob Storage operations."""

    def __init__(self):
        """Initialize Blob Storage client."""
        self.account_name = os.getenv("AZURE_STORAGE_ACCOUNT_NAME")
        self.account_key = os.getenv("AZURE_STORAGE_ACCOUNT_KEY")
        self.upload_container = os.getenv("AZURE_STORAGE_UPLOAD_CONTAINER", "upload-target")
        self.uploaded_container = os.getenv("AZURE_STORAGE_UPLOADED_CONTAINER", "uploaded")
        self.upload_max_concurrency = self._get_int_env("AZURE_BLOB_UPLOAD_CONCURRENCY", 4)
        self.download_max_concurrency = self._get_int_env("AZURE_BLOB_DOWNLOAD_CONCURRENCY", 4)
        self.upload_block_size_mb = self._get_int_env("AZURE_BLOB_UPLOAD_BLOCK_SIZE_MB", 4)

        if not self.account_name or not self.account_key:
            raise ValueError(
                "Azure Storage credentials not found in environment variables. "
                "Please set AZURE_STORAGE_ACCOUNT_NAME and AZURE_STORAGE_ACCOUNT_KEY"
            )

        # Initialize BlobServiceClient
        self.blob_service_client = BlobServiceClient(
            account_url=f"https://{self.account_name}.blob.core.windows.net",
            credential=self.account_key
        )

    @staticmethod
    def _get_int_env(name: str, default: int) -> int:
        try:
            value = int(os.getenv(name, default))
        except ValueError:
            return default
        return value if value > 0 else default

    def upload_file(self, file_path: str, blob_name: Optional[str] = None, container_name: Optional[str] = None) -> str:
        """
        Upload a file to Blob Storage.

        Args:
            file_path: Path to the local file
            blob_name: Name for the blob (defaults to filename)
            container_name: Container name (defaults to upload_container)

        Returns:
            Blob name
        """
        if container_name is None:
            container_name = self.upload_container

        if blob_name is None:
            blob_name = Path(file_path).name

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )

        with open(file_path, "rb") as data:
            upload_kwargs = {
                "overwrite": True,
                "max_concurrency": self.upload_max_concurrency,
                "timeout": 300  # 5分のタイムアウト
            }
            if self.upload_block_size_mb:
                upload_kwargs["max_block_size"] = self.upload_block_size_mb * 1024 * 1024
            try:
                blob_client.upload_blob(data, **upload_kwargs)
            except TypeError:
                # Fallback for older azure-storage-blob versions without these kwargs.
                blob_client.upload_blob(data, overwrite=True, timeout=300)

        return blob_name

    def download_file(self, blob_name: str, local_path: str, container_name: Optional[str] = None):
        """
        Download a file from Blob Storage.

        Args:
            blob_name: Name of the blob
            local_path: Path to save the file locally
            container_name: Container name (defaults to upload_container)
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )

        os.makedirs(os.path.dirname(local_path), exist_ok=True)

        with open(local_path, "wb") as download_file:
            try:
                downloader = blob_client.download_blob(max_concurrency=self.download_max_concurrency)
            except TypeError:
                downloader = blob_client.download_blob()
            download_file.write(downloader.readall())

    def list_blobs(self, container_name: Optional[str] = None, prefix: Optional[str] = None) -> List[str]:
        """
        List blobs in a container.

        Args:
            container_name: Container name (defaults to upload_container)
            prefix: Filter blobs by prefix

        Returns:
            List of blob names
        """
        if container_name is None:
            container_name = self.upload_container

        container_client = self.blob_service_client.get_container_client(container_name)

        if prefix:
            blobs = container_client.list_blobs(name_starts_with=prefix)
        else:
            blobs = container_client.list_blobs()

        return [blob.name for blob in blobs]

    def list_blobs_with_properties(
        self,
        container_name: Optional[str] = None,
        prefix: Optional[str] = None
    ) -> List[dict]:
        """
        List blobs with properties in a container.

        Returns:
            List of dicts with name, size, last_modified
        """
        if container_name is None:
            container_name = self.upload_container

        container_client = self.blob_service_client.get_container_client(container_name)

        if prefix:
            blobs = container_client.list_blobs(name_starts_with=prefix)
        else:
            blobs = container_client.list_blobs()

        results = []
        for blob in blobs:
            last_modified = blob.last_modified.isoformat() if blob.last_modified else ""
            results.append({
                "name": blob.name,
                "size": blob.size or 0,
                "last_modified": last_modified
            })
        return results

    def delete_blob(self, blob_name: str, container_name: Optional[str] = None):
        """
        Delete a blob from storage.

        Args:
            blob_name: Name of the blob
            container_name: Container name (defaults to upload_container)
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )

        blob_client.delete_blob()

    def get_blob_properties(self, blob_name: str, container_name: Optional[str] = None) -> dict:
        """
        Get blob properties.
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )
        props = blob_client.get_blob_properties()
        content_type = ""
        if props.content_settings and props.content_settings.content_type:
            content_type = props.content_settings.content_type
        last_modified = props.last_modified.isoformat() if props.last_modified else ""
        return {
            "size": props.size,
            "content_type": content_type,
            "last_modified": last_modified
        }

    def download_blob_to_bytes(
        self,
        blob_name: str,
        container_name: Optional[str] = None,
        offset: Optional[int] = None,
        length: Optional[int] = None
    ) -> bytes:
        """
        Download blob contents into memory.
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )
        try:
            downloader = blob_client.download_blob(
                offset=offset,
                length=length,
                max_concurrency=self.download_max_concurrency
            )
        except TypeError:
            downloader = blob_client.download_blob(
                offset=offset,
                length=length
            )
        return downloader.readall()

    def stream_blob(
        self,
        blob_name: str,
        container_name: Optional[str] = None,
        offset: Optional[int] = None,
        length: Optional[int] = None,
        chunk_size: int = 4 * 1024 * 1024
    ):
        """
        Stream blob contents in chunks.
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )
        try:
            downloader = blob_client.download_blob(
                offset=offset,
                length=length,
                max_concurrency=self.download_max_concurrency
            )
        except TypeError:
            downloader = blob_client.download_blob(
                offset=offset,
                length=length
            )
        return downloader.chunks(chunk_size=chunk_size)

    def move_blob(self, blob_name: str, source_container: Optional[str] = None, dest_container: Optional[str] = None):
        """
        Move a blob from one container to another.

        Args:
            blob_name: Name of the blob
            source_container: Source container (defaults to upload_container)
            dest_container: Destination container (defaults to uploaded_container)
        """
        if source_container is None:
            source_container = self.upload_container
        if dest_container is None:
            dest_container = self.uploaded_container

        # Copy to destination
        source_blob = self.blob_service_client.get_blob_client(source_container, blob_name)
        dest_blob = self.blob_service_client.get_blob_client(dest_container, blob_name)

        dest_blob.start_copy_from_url(source_blob.url)

        # Delete from source
        source_blob.delete_blob()

    def blob_exists(self, blob_name: str, container_name: Optional[str] = None) -> bool:
        """
        Check if a blob exists.

        Args:
            blob_name: Name of the blob
            container_name: Container name (defaults to upload_container)

        Returns:
            True if blob exists, False otherwise
        """
        if container_name is None:
            container_name = self.upload_container

        blob_client = self.blob_service_client.get_blob_client(
            container=container_name,
            blob=blob_name
        )

        return blob_client.exists()

    def get_blob_count(self, container_name: Optional[str] = None) -> int:
        """
        Get the number of blobs in a container.

        Args:
            container_name: Container name (defaults to upload_container)

        Returns:
            Number of blobs
        """
        return len(self.list_blobs(container_name))
