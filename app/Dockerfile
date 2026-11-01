FROM python:3.12-alpine

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN addgroup -S appgroup \
    && adduser -S appuser -G appgroup \
    && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app:app"]
