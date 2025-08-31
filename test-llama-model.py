#!/usr/bin/env python3
"""
Test script pour le modèle Llama-3.2-1B-Instruct déployé sur OpenShift AI
"""

import requests
import json
import time

# Configuration du modèle déployé
import os
from urllib.parse import urljoin

# Chargement des variables d'environnement
OPENSHIFT_PROJECT = os.getenv("OPENSHIFT_PROJECT", "llama-instruct-32-1b-demo")
OPENSHIFT_CLUSTER_DOMAIN = os.getenv("OPENSHIFT_CLUSTER_DOMAIN")

if not OPENSHIFT_CLUSTER_DOMAIN:
    print("❌ Variable OPENSHIFT_CLUSTER_DOMAIN non définie dans .env")
    print("Configurez votre fichier .env avec le bon domaine de cluster")
    exit(1)

# Construction de l'URL du modèle
MODEL_URL = f"https://llama-32-1b-instruct-{OPENSHIFT_PROJECT}.apps.{OPENSHIFT_CLUSTER_DOMAIN}"
CHAT_ENDPOINT = f"{MODEL_URL}/v1/chat/completions"
COMPLETION_ENDPOINT = f"{MODEL_URL}/v1/completions"
MODELS_ENDPOINT = f"{MODEL_URL}/v1/models"

def test_models_endpoint():
    """Test de l'endpoint /v1/models pour vérifier que le modèle est disponible"""
    print("🔍 Test de l'endpoint /v1/models...")
    try:
        response = requests.get(MODELS_ENDPOINT, timeout=30)
        print(f"✅ Status: {response.status_code}")
        if response.status_code == 200:
            models = response.json()
            print(f"📋 Modèles disponibles: {json.dumps(models, indent=2)}")
            return True
        else:
            print(f"❌ Erreur: {response.text}")
            return False
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def test_chat_completion():
    """Test de l'endpoint /v1/chat/completions"""
    print("\n💬 Test de l'endpoint /v1/chat/completions...")
    
    payload = {
        "model": "llama-32-1b-instruct",
        "messages": [
            {
                "role": "system",
                "content": "Tu es un assistant IA utile et amical. Réponds en français de manière claire et concise."
            },
            {
                "role": "user",
                "content": "Salut ! Peux-tu me dire en quoi consiste le modèle Llama-3.2-1B-Instruct ?"
            }
        ],
        "max_tokens": 200,
        "temperature": 0.7,
        "stream": False
    }
    
    try:
        print("📤 Envoi de la requête...")
        response = requests.post(
            CHAT_ENDPOINT,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        
        print(f"✅ Status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"🤖 Réponse du modèle:")
            print(f"   - Modèle utilisé: {result.get('model', 'N/A')}")
            print(f"   - Tokens utilisés: {result.get('usage', {}).get('total_tokens', 'N/A')}")
            print(f"   - Réponse: {result['choices'][0]['message']['content']}")
            return True
        else:
            print(f"❌ Erreur: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def test_completion():
    """Test de l'endpoint /v1/completions (format legacy)"""
    print("\n📝 Test de l'endpoint /v1/completions...")
    
    payload = {
        "model": "llama-32-1b-instruct",
        "prompt": "Explique-moi ce qu'est l'intelligence artificielle en 2 phrases:",
        "max_tokens": 100,
        "temperature": 0.5,
        "stream": False
    }
    
    try:
        print("📤 Envoi de la requête...")
        response = requests.post(
            COMPLETION_ENDPOINT,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        
        print(f"✅ Status: {response.status_code}")
        if response.status_code == 200:
            result = response.json()
            print(f"🤖 Réponse du modèle:")
            print(f"   - Modèle utilisé: {result.get('model', 'N/A')}")
            print(f"   - Tokens utilisés: {result.get('usage', {}).get('total_tokens', 'N/A')}")
            print(f"   - Réponse: {result['choices'][0]['text']}")
            return True
        else:
            print(f"❌ Erreur: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Exception: {e}")
        return False

def main():
    """Fonction principale de test"""
    print("🚀 Test du modèle Llama-3.2-1B-Instruct sur OpenShift AI")
    print("=" * 60)
    
    # Test 1: Vérification des modèles disponibles
    models_ok = test_models_endpoint()
    
    if not models_ok:
        print("\n❌ Le modèle n'est pas accessible. Vérifiez le statut de l'InferenceService.")
        return
    
    # Attendre un peu que le modèle soit complètement chargé
    print("\n⏳ Attente de 10 secondes pour que le modèle soit prêt...")
    time.sleep(10)
    
    # Test 2: Test de chat completion
    chat_ok = test_chat_completion()
    
    # Test 3: Test de completion
    completion_ok = test_completion()
    
    # Résumé des tests
    print("\n" + "=" * 60)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 60)
    print(f"✅ Endpoint /v1/models: {'OK' if models_ok else 'ÉCHEC'}")
    print(f"✅ Chat completion: {'OK' if chat_ok else 'ÉCHEC'}")
    print(f"✅ Completion: {'OK' if completion_ok else 'ÉCHEC'}")
    
    if all([models_ok, chat_ok, completion_ok]):
        print("\n🎉 TOUS LES TESTS SONT PASSÉS ! Le modèle Llama fonctionne parfaitement !")
    else:
        print("\n⚠️  Certains tests ont échoué. Vérifiez la configuration du modèle.")

if __name__ == "__main__":
    main()
