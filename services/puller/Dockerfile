FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY puller_app ./puller_app

CMD ["python", "-u", "-m", "puller_app.main"]