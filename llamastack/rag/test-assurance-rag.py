#!/usr/bin/env python3
"""
Script de test RAG pour le use case assurance
Teste la fonctionnalité RAG avec des documents d'assurance
"""

import os
import uuid
from llama_stack_client import Client, Agent, AgentEventLogger

def test_assurance_rag():
    """Test de la fonctionnalité RAG pour l'assurance"""
    
    # Configuration
    LLAMA_STACK_URL = os.getenv('LLAMA_STACK_URL', 'http://localhost:8321')
    MODEL_ID = os.getenv('MODEL_ID', 'llama-32-1b-instruct')
    VECTOR_DB_ID = os.getenv('VECTOR_DB_ID', 'assurance_milvus_db')
    
    print(f"🔗 Connexion à LlamaStack: {LLAMA_STACK_URL}")
    print(f"🤖 Modèle: {MODEL_ID}")
    print(f"🗄️  Base vectorielle: {VECTOR_DB_ID}")
    print("🏢 Use Case: Assurance")
    print("-" * 60)
    
    try:
        # Connexion au client LlamaStack
        client = Client(base_url=LLAMA_STACK_URL)
        print("✅ Connexion à LlamaStack réussie")
        
        # Vérifier que la base vectorielle existe
        print(f"\n🗄️  Vérification de la base '{VECTOR_DB_ID}'...")
        vector_dbs = client.vector_dbs.list()
        target_db = next((db for db in vector_dbs if db.identifier == VECTOR_DB_ID), None)
        
        if not target_db:
            print(f"⚠️  Base vectorielle '{VECTOR_DB_ID}' non trouvée")
            print("   Bases disponibles:")
            for db in vector_dbs:
                print(f"   - {db.identifier}")
            return False
        
        print(f"✅ Base vectorielle trouvée: {target_db.identifier}")
        
        # Créer un agent RAG spécialisé assurance
        print("\n🤖 Création de l'agent RAG Assurance...")
        assurance_agent = Agent(
            client,
            model=MODEL_ID,
            instructions="""Tu es un expert en assurance spécialisé dans l'analyse de documents d'assurance. 
            Tu peux répondre aux questions sur les polices d'assurance, les garanties, les exclusions, 
            les procédures de sinistre et les aspects réglementaires. Utilise les informations de la 
            base de connaissances pour fournir des réponses précises et utiles.""",
            tools=[
                {
                    "name": "builtin::rag/knowledge_search",
                    "args": {"vector_db_ids": [VECTOR_DB_ID]},
                }
            ],
        )
        print("✅ Agent RAG Assurance créé")
        
        # Questions spécifiques à l'assurance
        assurance_questions = [
            "Quelles sont les garanties de base d'une assurance auto ?",
            "Comment fonctionne la procédure de déclaration de sinistre ?",
            "Quelles sont les exclusions courantes dans les polices d'assurance ?",
            "Quels sont les facteurs qui influencent le prix d'une assurance ?",
            "Quelles sont les obligations de l'assuré en cas de sinistre ?",
            "Comment choisir la bonne couverture d'assurance ?",
            "Quels sont les délais de prescription en assurance ?",
            "Comment fonctionne la franchise en assurance ?"
        ]
        
        print(f"\n🔍 Test de {len(assurance_questions)} questions d'assurance...")
        
        for i, question in enumerate(assurance_questions, 1):
            print(f"\n📝 Question {i}: {question}")
            
            # Créer une session
            session_id = assurance_agent.create_session(session_name=f"assurance_session_{uuid.uuid4().hex[:8]}")
            
            # Envoyer la requête
            response = assurance_agent.create_turn(
                messages=[{"role": "user", "content": question}],
                session_id=session_id,
                stream=True,
            )
            
            # Afficher la réponse
            print("💬 Réponse:")
            response_content = ""
            for log in AgentEventLogger().log(response):
                if hasattr(log, 'content') and log.content:
                    response_content += log.content
                    print(f"  {log.content}", end='', flush=True)
            
            # Analyser la réponse
            if response_content.strip():
                print(f"\n✅ Réponse reçue ({len(response_content)} caractères)")
            else:
                print(f"\n⚠️  Aucune réponse reçue")
            
            print("\n" + "-" * 40)
        
        # Test de requête directe sur la base vectorielle
        print("\n🔍 Test de requête directe sur la base vectorielle...")
        assurance_queries = [
            "assurance automobile garanties",
            "sinistre procédure déclaration",
            "exclusions police assurance",
            "franchise conditions"
        ]
        
        for query in assurance_queries:
            print(f"\n🔎 Requête: '{query}'")
            try:
                query_result = client.vector_io.query(
                    vector_db_id=VECTOR_DB_ID,
                    query=query,
                )
                
                if query_result and hasattr(query_result, 'results') and query_result.results:
                    print(f"✅ {len(query_result.results)} résultats trouvés")
                    for j, result in enumerate(query_result.results[:2], 1):  # Afficher les 2 premiers
                        print(f"  Résultat {j}: {result.content[:150]}...")
                else:
                    print("ℹ️  Aucun résultat trouvé")
                    
            except Exception as e:
                print(f"❌ Erreur lors de la requête: {e}")
        
        print("\n🎉 Tests RAG Assurance terminés avec succès!")
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test RAG Assurance: {e}")
        return False

def test_assurance_scenarios():
    """Test de scénarios d'assurance spécifiques"""
    
    LLAMA_STACK_URL = os.getenv('LLAMA_STACK_URL', 'http://localhost:8321')
    MODEL_ID = os.getenv('MODEL_ID', 'llama-32-1b-instruct')
    VECTOR_DB_ID = os.getenv('VECTOR_DB_ID', 'assurance_milvus_db')
    
    print(f"\n🎭 Test de scénarios d'assurance...")
    
    try:
        client = Client(base_url=LLAMA_STACK_URL)
        
        # Scénarios d'assurance
        scenarios = [
            {
                "name": "Accident de voiture",
                "question": "J'ai eu un accident de voiture hier. Que dois-je faire dans les 24h qui suivent ?"
            },
            {
                "name": "Vol à domicile",
                "question": "Mon appartement a été cambriolé. Quelles sont mes obligations vis-à-vis de mon assureur ?"
            },
            {
                "name": "Dégât des eaux",
                "question": "J'ai un dégât des eaux dans ma salle de bain. Comment procéder pour être indemnisé ?"
            },
            {
                "name": "Résiliation d'assurance",
                "question": "Je veux changer d'assureur. Quels sont les délais de préavis et les formalités ?"
            }
        ]
        
        assurance_agent = Agent(
            client,
            model=MODEL_ID,
            instructions="Tu es un expert en assurance. Réponds aux questions en te basant sur les documents d'assurance disponibles.",
            tools=[
                {
                    "name": "builtin::rag/knowledge_search",
                    "args": {"vector_db_ids": [VECTOR_DB_ID]},
                }
            ],
        )
        
        for scenario in scenarios:
            print(f"\n🎭 Scénario: {scenario['name']}")
            print(f"❓ Question: {scenario['question']}")
            
            session_id = assurance_agent.create_session(session_name=f"scenario_{uuid.uuid4().hex[:8]}")
            response = assurance_agent.create_turn(
                messages=[{"role": "user", "content": scenario['question']}],
                session_id=session_id,
                stream=True,
            )
            
            print("💬 Réponse:")
            for log in AgentEventLogger().log(response):
                if hasattr(log, 'content') and log.content:
                    print(f"  {log.content}", end='', flush=True)
            print("\n")
        
        return True
        
    except Exception as e:
        print(f"❌ Erreur lors du test des scénarios: {e}")
        return False

if __name__ == "__main__":
    print("🏢 Test de la fonctionnalité RAG - Use Case Assurance")
    print("=" * 70)
    
    # Test principal RAG assurance
    rag_success = test_assurance_rag()
    
    # Test des scénarios
    scenarios_success = test_assurance_scenarios()
    
    # Résumé
    print("\n" + "=" * 70)
    print("📊 RÉSUMÉ DES TESTS ASSURANCE")
    print("=" * 70)
    print(f"RAG Assurance: {'✅ SUCCESS' if rag_success else '❌ FAILED'}")
    print(f"Scénarios Assurance: {'✅ SUCCESS' if scenarios_success else '❌ FAILED'}")
    
    if rag_success and scenarios_success:
        print("\n🎉 Tous les tests assurance sont passés avec succès!")
        print("🏢 Le système RAG est prêt pour le use case assurance!")
    else:
        print("\n⚠️  Certains tests assurance ont échoué.")
        print("   Vérifiez que les documents d'assurance ont été ingérés correctement.")
