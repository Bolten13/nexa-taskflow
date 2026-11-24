# ==========================================
# ETAPE 1 : Construction de l'environnement
# ==========================================

FROM python:3.12-slim AS builder

WORKDIR /build

# Creer un environnement virtuel Python
RUN python -m venv /opt/venv

# Utiliser cet environnement pour installer les dependances
ENV PATH="/opt/venv/bin:$PATH"

# Copier uniquement les dependances
COPY requirements.txt .

# Mettre a jour pip et installer les dependances
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt


# ==========================================
# ETAPE 2 : Image finale de production
# ==========================================

FROM python:3.12-slim AS runtime

WORKDIR /app

# Recuperer uniquement l'environnement Python construit
# Copier les dependances depuis le builder
COPY --from=builder /opt/venv /opt/venv

# Retirer les outils d'installation inutiles en production
RUN rm -rf /opt/venv/lib/python3.12/site-packages/pip \
           /opt/venv/lib/python3.12/site-packages/pip-*.dist-info \
           /opt/venv/bin/pip \
           /opt/venv/bin/pip3 \
           /opt/venv/bin/pip3.12 \
           /usr/local/lib/python3.12/site-packages/pip \
           /usr/local/lib/python3.12/site-packages/pip-*.dist-info \
           /usr/local/bin/pip \
           /usr/local/bin/pip3 \
           /usr/local/bin/pip3.12

ENV PATH="/opt/venv/bin:$PATH"

COPY app/ ./app/

# Creer un utilisateur non privilegie
RUN useradd --create-home --uid 10001 taskflow \
    && chown -R taskflow:taskflow /app

# Executer l'application sans les privileges root
USER taskflow

EXPOSE 8085

# Demarrer TaskFlow
CMD ["python", "-m", "app.app"]