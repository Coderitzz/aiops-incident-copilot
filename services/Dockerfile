# One multi-stage Dockerfile for all services:
#   docker build --build-arg SERVICE=order-service .
FROM python:3.12-slim AS builder
ARG SERVICE
WORKDIR /build
COPY common/requirements.txt common-requirements.txt
COPY ${SERVICE}/requirements.txt service-requirements.txt
RUN pip install --no-cache-dir --prefix=/install -r common-requirements.txt -r service-requirements.txt

FROM python:3.12-slim
ARG SERVICE
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
RUN useradd --create-home --uid 10001 app
WORKDIR /app
COPY --from=builder /install /usr/local
COPY common ./common
COPY ${SERVICE}/app ./app
USER app
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
