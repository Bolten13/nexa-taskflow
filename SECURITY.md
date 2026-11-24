# Politique de gestion des vulnérabilités – TaskFlow

## 1. Périmètre et contexte

TaskFlow est une API accessible sur Internet et utilisée par une application mobile.

L'application traite des données personnelles, notamment des comptes utilisateurs et des mots de passe hachés. Elle communique également avec un prestataire de paiement externe, PayCorp, au moyen d'une clé API.

L'infrastructure repose sur AWS, Docker et Kubernetes.

L'équipe de développement comprend trois développeurs et réalise une mise en production par semaine. Aucune astreinte n'est assurée le week-end.

La présente politique couvre :
- Le code source de l'application ;
- Les dépendances Python directes et transitives ;
- Les images Docker et leurs composants système ;
- Les configurations d'infrastructure ;
- Les secrets et les éléments de la chaîne CI/CD.

## 2. Classification et délais de correction

| Sévérité | Politique CI/CD | Délai maximal de correction |
|---|---|---|
| CRITICAL | Bloquant | 72 heures |
| HIGH | Bloquant si un correctif existe | 30 jours |
| MEDIUM | Informatif | 90 jours |
| LOW | Informatif | Prochaine maintenance |
| UNKNOWN | Analyse manuelle obligatoire | 15 jours pour qualifier |

Les vulnérabilités présentes dans le catalogue KEV de la CISA doivent être traitées en priorité.

Une vulnérabilité HIGH présentant une forte probabilité d'exploitation (EPSS élevé) peut être reclassée en priorité critique.

Les délais courent à partir de la détection. Les vulnérabilités critiques découvertes pendant un week-end nécessitent une escalade immédiate au responsable du projet. L'absence d'astreinte représente un risque organisationnel à résoudre avant toute exploitation en production.

## 3. Contrôles automatisés

Les analyses de sécurité sont réalisées avec les outils suivants :

- **Semgrep** : analyse statique du code ;
- **Gitleaks** : détection des secrets ;
- **Trivy filesystem** : analyse des dépendances ;
- **Trivy image** : analyse des images Docker.

Les contrôles sont exécutés dans GitHub Actions lors des push et des pull requests.

La pipeline doit refuser une modification introduisant :
- Une vulnérabilité CRITICAL ;
- Une vulnérabilité HIGH pour laquelle un correctif est disponible ;
- Une vulnérabilité de code bloquante détectée par Semgrep ;
- Un nouveau secret détecté par Gitleaks.

Les vulnérabilités MEDIUM et LOW font l'objet d'un suivi sans blocage systématique.

Les vulnérabilités UNKNOWN doivent être qualifiées manuellement et ne peuvent pas être considérées automatiquement comme sans risque.

## 4. Politique de durcissement des images

Les images Docker doivent respecter les principes suivants :

- Utiliser une image de base minimale et maintenue ;
- Éviter les versions non figées ;
- Utiliser une construction multi-étapes lorsque cela permet de réduire les composants présents à l'exécution ;
- Exécuter l'application avec un utilisateur non privilégié ;
- Supprimer les fichiers temporaires et les outils de construction inutiles ;
- Exclure les secrets et les fichiers locaux du contexte Docker ;
- Reconstruire régulièrement les images pour intégrer les correctifs de sécurité.

## 5. Gestion des exceptions

Toute exception de sécurité doit être justifiée et limitée dans le temps.

Une exception doit obligatoirement comporter :

- L'identifiant de vulnérabilité (CVE) ;
- Le composant et la version concernés ;
- La justification technique de l'exception ;
- Les mesures compensatoires mises en place ;
- Le responsable de l'acceptation du risque ;
- Une date d'expiration ;
- Une référence de suivi.

Les exceptions sont enregistrées dans le fichier `.trivyignore`, lorsque le format de l'outil le permet.

Une exception expirée ne doit plus être considérée comme valable.

Aucune exception ne peut être créée uniquement pour obtenir un résultat positif dans la pipeline.

## 6. Responsabilités

| Rôle | Responsabilité |
|---|---|
| Développeurs TaskFlow | Corriger les dépendances et les vulnérabilités applicatives |
| Responsable sécurité du projet | Qualifier les alertes et valider les exceptions |
| Responsable du dépôt GitHub | Maintenir les contrôles de sécurité CI/CD |
| Responsable de mise en production | Vérifier les résultats avant déploiement |

Dans le cadre du TP DevSecOps, ces responsabilités sont simulées et assurées par l'étudiant.

## 7. Suivi et révision

Les résultats Trivy sont conservés afin de comparer les vulnérabilités avant et après correction.

Un contrôle de sécurité doit être effectué avant chaque mise en production.

La politique est réévaluée au minimum tous les trois mois et après tout incident de sécurité majeur.

**Date de création :** 24 novembre 2026  
**Prochaine révision :** 24 février 2027  
**Projet :** TaskFlow – TP DevSecOps – NEXA Digital School