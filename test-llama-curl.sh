#!/bin/bash

# Test script pour le modèle Llama-3.2-1B-Instruct avec curl
# Chargement des variables d'environnement
if [ -f .env ]; then
    source .env
else
    echo "❌ Fichier .env non trouvé. Copiez env-template vers .env et configurez vos valeurs."
    exit 1
fi

# Vérification des variables obligatoires
if [ -z "$OPENSHIFT_CLUSTER_DOMAIN" ]; then
    echo "❌ Variable OPENSHIFT_CLUSTER_DOMAIN non définie dans .env"
    echo "Configurez votre fichier .env avec le bon domaine de cluster"
    exit 1
fi

# Construction de l'URL du modèle
MODEL_URL="https://llama-32-1b-instruct-${OPENSHIFT_PROJECT}.apps.${OPENSHIFT_CLUSTER_DOMAIN}"

echo "🚀 Test du modèle Llama-3.2-1B-Instruct avec curl"
echo "=================================================="

# Test 1: Vérification des modèles disponibles
echo -e "\n🔍 Test de l'endpoint /v1/models..."
curl -s -X GET "${MODEL_URL}/v1/models" | jq '.' 2>/dev/null || echo "❌ Erreur ou jq non installé"

# Test 2: Test de chat completion
echo -e "\n💬 Test de l'endpoint /v1/chat/completions..."
curl -s -X POST "${MODEL_URL}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-32-1b-instruct",
    "messages": [
      {
        "role": "system",
        "content": "Tu es un assistant IA utile. Réponds en français."
      },
      {
        "role": "user",
        "content": "Dis-moi bonjour en français."
      }
    ],
    "max_tokens": 50,
    "temperature": 0.7
  }' | jq '.' 2>/dev/null || echo "❌ Erreur ou jq non installé"

# Test 3: Test de completion simple
echo -e "\n📝 Test de l'endpoint /v1/completions..."
curl -s -X POST "${MODEL_URL}/v1/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-32-1b-instruct",
    "prompt": "Bonjour, comment allez-vous ?",
    "max_tokens": 30,
    "temperature": 0.5
  }' | jq '.' 2>/dev/null || echo "❌ Erreur ou jq non installé"

echo -e "\n✅ Tests terminés !"
