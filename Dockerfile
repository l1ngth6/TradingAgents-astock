FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /build
COPY . .
RUN pip install --no-cache-dir .

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

ARG APP_UID=1000
ARG APP_GID=1000

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# CJK fonts so PDF export (fpdf2) can render Chinese reports inside the container
# (issue #48 — the slim image ships no CJK font, so _find_cjk_font() returns None).
RUN apt-get update \
    && apt-get install -y --no-install-recommends fonts-wqy-microhei fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

RUN if getent group "${APP_GID}" >/dev/null; then \
        true; \
    else \
        groupadd --gid "${APP_GID}" appuser; \
    fi \
    && useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home appuser \
    && install -d -m 0755 -o "${APP_UID}" -g "${APP_GID}" \
       /home/appuser/.tradingagents/cache \
       /home/appuser/.tradingagents/logs \
       /home/appuser/.tradingagents/memory \
       /home/appuser/app \
       /home/appuser/app/reports

WORKDIR /home/appuser/app

COPY --from=builder --chown=${APP_UID}:${APP_GID} /build .
COPY docker/entrypoint.py /usr/local/bin/tradingagents-entrypoint.py

# Entrypoint starts as root only to repair mounted-directory ownership, then
# permanently drops privileges before executing either CLI or Web command.
USER root
ENTRYPOINT ["python", "/usr/local/bin/tradingagents-entrypoint.py"]
CMD ["tradingagents"]
