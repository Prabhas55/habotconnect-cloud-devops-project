# Use official Python image
FROM python:3.11-slim

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application
COPY . .

# Expose Django port
EXPOSE 8000

# Collect static files (ignore if not configured)
RUN python manage.py collectstatic --noinput || true

# Start Django
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
