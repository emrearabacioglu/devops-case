FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY ETL.py ./
RUN useradd -m etluser
USER etluser
CMD ["python", "ETL.py"]