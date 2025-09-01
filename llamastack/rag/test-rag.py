#!/usr/bin/env python3
"""
Script de test pour la fonctionnalité RAG avec LlamaStack
Basé sur la documentation Red Hat OpenShift AI
"""

import os
import uuid
from llama_stack_client import Client, Agent, AgentEventLogger

def test_rag_functionality():
    """Test de la fonctionnalité RAG avec LlamaStack"""
    
    # Configuration
    LLAMA_STACK_URL = os.getenv('LLAMA_STACK_URL', 'http://localhost:8321')
    MODEL_ID = os.getenv('MODEL_ID', 'llama-32-1b-instruct')
    VECTOR_DB_ID = os.getenv('VECTOR_DB_ID', 'my_milvus_db')
    
    print(f"🔗 Connexion à LlamaStack: {LLAMA_STACK_URL}")
    print(f"🤖 Modèle: {MODEL_ID}")
    print(f"🗄️  Base vectorielle: {VECTOR_DB_ID}")
    print("-" * 50)
    
    try:
        # Connexion au client LlamaStack
        client = Client(base_url=LLAMA_STACK_URL)
        print("✅ Connexion à LlamaStack réussie")
        
        # Lister les modèles disponibles
        print("\n📋 Modèles disponibles:")
        models = client.models.list()
        for model in models:
            print(f"  - {model.identifier} ({model.model_type})")
        
        # Vérifier que le modèle LLM est disponible
        llm_model = next((m for m in models if m.model_type == "llm"), None)
        if not llm_model:
            print("❌ Aucun modèle LLM trouvé")
            return False
        
        print(f"✅ Modèle LLM trouvé: {llm_model.identifier}")
        
        # Vérifier les bases vectorielles disponibles
        print("\n🗄️  Bases vectorielles disponibles:")
        vector_dbs = client.vector_dbs.list()
        for db in vector_dbs:
            print(f"  - {db.identifier}")
        
        # Vérifier que la base vectorielle existe
        target_db = next((db for db in vector_dbs if db.identifier == VECTOR_DB_ID), None)
        if not target_db:
            print(f"❌ Base vectorielle '{VECTOR_DB_ID}' non trouvée")
            return False
        
        print(f"✅ Base vectorielle trouvée: {target_db.identifier}")
        
        # Créer un agent RAG
        print("\n🤖 Création de l'agent RAG...")
        rag_agent = Agent(
            client,
            model=llm_model.identifier,
            instructions="Tu es un assistant IA spécialisé dans l'analyse de documents. Utilise les informations de la base de connaissances pour répondre aux questions.",
            tools=[
                {
                    "name": "builtin::rag/knowledge_search",
                    "args": {"vector_db_ids": [VECTOR_DB_ID]},
                }
            ],
        )
        print("✅ Agent RAG créé")
        
        # Test de requête RAG
        print("\n🔍 Test de requête RAG...")
        test_questions = [
            "Que sais-tu sur les documents que tu as analysés ?",
            "Peux-tu me donner un résumé des informations disponibles ?",
            "Y a-t-il des détails techniques importants dans les documents ?"
        ]
        
        for i, question in enumerate(test_questions, 1):
            print(f"\n📝 Question {i}: {question}")
            
            # Créer une session
            session_id = rag_agent.create_session(session_name=f"test_session_{uuid.uuid4().hex[:8]}")
            
            # Envoyer la requête
            response = rag_agent.create_turn(
                messages=[{"role": "user", "content": question}],
                session_id=session_id,
                stream=True,
            )
            
            # Afficher la réponse
            print("💬 Réponse:")
            for log in AgentEventLogger().log(response):
                if hasattr(log, 'content') and log.content:
                    print(f"  {log.content}", end='', flush=True)
            print("\n")
        
        # Test de requête directe sur la base vectorielle
        print("\n🔍 Test de requête directe sur la base vectorielle...")
        query_result = client.vector_io.query(
            vector_db_id=VECTOR_DB_ID,
            query="informations importantes",
        )
        
        if query_result and hasattr(query_result, 'results'):
            print(f"✅ {len(query_result.results)} résultats trouvés")
            for i, result in enumerate(query_result.results[:3], 1):  # Afficher les 3 premiers
                print(f"  Résultat {i}: {result.content[:100]}...")
        else:
            print("ℹ️  Aucun résultat trouvé (base vide ou requête sans correspondance)")
        
        print("\n🎉 Tests RAG terminés avec succès!")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test RAG: {e}")
        return False

def test_vector_db_operations():
    """Test des opérations sur la base vectorielle"""
    
    LLAMA_STACK_URL = os.getenv('LLAMA_STACK_URL', 'http://localhost:8321')
    VECTOR_DB_ID = os.getenv('VECTOR_DB_ID', 'my_milvus_db')
    
    print(f"\n🗄️  Test des opérations sur la base vectorielle...")
    
    try:
        client = Client(base_url=LLAMA_STACK_URL)
        
        # Lister les providers disponibles
        print("📋 Providers de base vectorielle disponibles:")
        providers = client.vector_dbs.list_providers()
        for provider in providers:
            print(f"  - {provider}")
        
        # Vérifier le statut de la base
        print(f"\n📊 Statut de la base '{VECTOR_DB_ID}':")
        try:
            db_info = client.vector_dbs.get(VECTOR_DB_ID)
            print(f"  - ID: {db_info.identifier}")
            print(f"  - Provider: {db_info.provider_id}")
            print(f"  - Modèle d'embedding: {db_info.embedding_model}")
            print(f"  - Dimension: {db_info.embedding_dimension}")
        except Exception as e:
            print(f"  - Erreur: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test de la base vectorielle: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Test de la fonctionnalité RAG avec LlamaStack")
    print("=" * 60)
    
    # Test principal RAG
    rag_success = test_rag_functionality()
    
    # Test des opérations sur la base vectorielle
    vector_success = test_vector_db_operations()
    
    # Résumé
    print("\n" + "=" * 60)
    print("📊 RÉSUMÉ DES TESTS")
    print("=" * 60)
    print(f"RAG Functionality: {'✅ SUCCESS' if rag_success else '❌ FAILED'}")
    print(f"Vector DB Operations: {'✅ SUCCESS' if vector_success else '❌ FAILED'}")
    
    if rag_success and vector_success:
        print("\n🎉 Tous les tests sont passés avec succès!")
    else:
        print("\n⚠️  Certains tests ont échoué. Vérifiez la configuration.")
