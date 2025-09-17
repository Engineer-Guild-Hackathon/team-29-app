FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt ./
# Install Tesseract OCR engine and Japanese language data
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       tesseract-ocr \
       tesseract-ocr-jpn \
       tesseract-ocr-jpn-vert \
    && rm -rf /var/lib/apt/lists/*

# Python deps
RUN pip install --no-cache-dir -r requirements.txt
COPY app/ /app/
RUN mkdir -p /data/uploads
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
