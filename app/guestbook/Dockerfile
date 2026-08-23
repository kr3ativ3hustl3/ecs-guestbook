# Small, specific base image rather than a full OS image — smaller
# attack surface, faster pulls, less to patch.
FROM python:3.12-slim

WORKDIR /app

# Copy requirements first and install before copying the rest of the
# code — Docker caches layers, so this means a code-only change
# doesn't force a full dependency reinstall on every build.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates/ templates/

# Runs as a non-root user — a container escape shouldn't hand over
# root on the host by default.
RUN useradd --create-home appuser
USER appuser

EXPOSE 8080

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "app:app"]
