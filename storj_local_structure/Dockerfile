FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY file_organizer.py .

# Create directories for source and organized files
RUN mkdir -p /app/source_files /app/organized_files

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Default command
CMD ["python", "file_organizer.py", "status"]