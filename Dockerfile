FROM python:3.12-slim

WORKDIR /app

# Installer les dépendances Python
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copier les fichiers de l'application
COPY . .

# Créer un utilisateur sans privilèges administrateur
RUN useradd --create-home --uid 10001 taskflow \
    && chown -R taskflow:taskflow /app

# Exécuter l'application sans les privilèges root
USER taskflow

EXPOSE 8085

CMD ["python", "-m", "app.app"]