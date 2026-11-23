import os

# Configuration de la base de données
DATABASE = os.environ.get("TASKFLOW_DB", "taskflow.db")

# Clé du prestataire de paiement
# Récupération depuis une variable d'environnement
PAYMENT_API_KEY = os.environ.get("PAYMENT_API_KEY", "")