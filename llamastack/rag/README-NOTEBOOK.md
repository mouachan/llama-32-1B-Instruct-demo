# 📓 Notebook de Test LlamaStack

Ce notebook Jupyter permet de tester la fonctionnalité LlamaStack dans OpenShift AI.

## 🎯 Objectif

Tester la connexion et les fonctionnalités de base de LlamaStack avec le modèle Llama-3.2-1B-Instruct déployé.

## 📋 Prérequis

- OpenShift AI Workbench (Data Science) démarré
- Modèle Llama-3.2-1B-Instruct déployé et fonctionnel
- LlamaStackDistribution déployée et en cours d'exécution

## 🚀 Utilisation

1. **Ouvrir le notebook** dans OpenShift AI Workbench
2. **Exécuter les cellules** dans l'ordre
3. **Vérifier les résultats** de chaque test

## 🔗 Services testés

- **LlamaStack** : `http://lsd-llama-32-1b-instruct-service:8321`
- **vLLM** : `http://llama-32-1b-instruct-predictor:80`

## 📊 Tests inclus

1. **Vérification des services** - Test de connexion HTTP
2. **Client LlamaStack** - Connexion et listing des modèles
3. **Agent LlamaStack** - Création d'un agent et test de conversation
4. **Base vectorielle** - Test RAG (si disponible)

## ⚠️ Notes importantes

- Le notebook utilise uniquement les **services internes** (pas de routes externes)
- Les tests sont conçus pour s'exécuter **dans le cluster OpenShift**
- Si les tests échouent, vérifiez que tous les services sont démarrés

## 🔧 Dépannage

Si les tests échouent :

1. Vérifiez que LlamaStackDistribution est en cours d'exécution :
   ```bash
   oc get llamastackdistribution -n llama-instruct-32-1b-demo
   ```

2. Vérifiez que l'InferenceService est prêt :
   ```bash
   oc get inferenceservice -n llama-instruct-32-1b-demo
   ```

3. Consultez les logs si nécessaire :
   ```bash
   oc logs -f deployment/lsd-llama-32-1b-instruct -n llama-instruct-32-1b-demo
   ```
