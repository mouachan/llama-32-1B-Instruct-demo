# 🗄️ RAG (Retrieval-Augmented Generation) avec LlamaStack

Ce répertoire contient la configuration pour déployer une fonctionnalité RAG (Retrieval-Augmented Generation) avec LlamaStack et Docling sur OpenShift AI.

## 📋 Vue d'ensemble

La fonctionnalité RAG permet d'ingérer des documents dans une base vectorielle (Milvus) et d'utiliser ces informations pour enrichir les réponses du modèle Llama-3.2-1B-Instruct.

### 🏗️ Architecture RAG

```
Documents PDF → Docling Pipeline → Milvus Vector DB → LlamaStack → Llama Model
```

## 📁 Structure des fichiers

```
llamastack/rag/
├── README.md                    # Cette documentation
├── docling-pipeline.yaml        # Pipeline Tekton pour l'ingestion de documents
├── deploy-rag.sh               # Script de déploiement automatisé
└── test-rag.py                 # Script de test de la fonctionnalité RAG
```

## 🚀 Déploiement

### Prérequis

1. **LlamaStackDistribution** doit être déployé et fonctionnel
2. **Namespace** `llama-instruct-32-1b-demo` doit exister
3. **Connexion OpenShift** active
4. **Python** avec `llama_stack_client` installé

### Déploiement automatisé

```bash
cd llamastack/rag
chmod +x deploy-rag.sh
./deploy-rag.sh
```

### Déploiement manuel

1. **Déployer le pipeline Docling :**
   ```bash
   oc apply -f docling-pipeline.yaml
   ```

2. **Créer un PipelineRun de test :**
   ```bash
   # Modifier les paramètres selon vos besoins
   oc apply -f - << EOF
   apiVersion: tekton.dev/v1
   kind: PipelineRun
   metadata:
     name: docling-test-run
     namespace: llama-instruct-32-1b-demo
   spec:
     pipelineRef:
       name: docling-pipeline
     params:
       - name: base_url
         value: "https://example.com/pdfs"
       - name: pdf_filenames
         value: "document1.pdf,document2.pdf"
       - name: vector_db_id
         value: "my_milvus_db"
       - name: embed_model_id
         value: "granite-embedding-125m"
       - name: max_tokens
         value: "512"
       - name: use_gpu
         value: "false"
     workspaces:
       - name: shared-workspace
         volumeClaimTemplate:
           spec:
             accessModes: ["ReadWriteOnce"]
             resources:
               requests:
                 storage: 1Gi
   EOF
   ```

## 🧪 Tests

### Test de la fonctionnalité RAG

```bash
# Configurer les variables d'environnement
export LLAMA_STACK_URL="http://localhost:8321"
export MODEL_ID="llama-32-1b-instruct"
export VECTOR_DB_ID="my_milvus_db"

# Exécuter le test
python3 test-rag.py
```

### Vérification du statut

```bash
# Vérifier le statut du PipelineRun
oc get pipelinerun -n llama-instruct-32-1b-demo

# Voir les logs du pipeline
oc logs pipelinerun/docling-test-run -n llama-instruct-32-1b-demo

# Vérifier LlamaStackDistribution
oc get llamastackdistribution -n llama-instruct-32-1b-demo
```

## ⚙️ Configuration

### Paramètres du pipeline Docling

| Paramètre | Description | Défaut |
|-----------|-------------|---------|
| `base_url` | URL de base pour récupérer les PDFs | `https://example.com/pdfs` |
| `pdf_filenames` | Liste des fichiers PDF (séparés par virgules) | `document1.pdf,document2.pdf` |
| `num_workers` | Nombre de workers parallèles | `2` |
| `vector_db_id` | ID de la base vectorielle Milvus | `my_milvus_db` |
| `service_url` | URL du service Milvus | `http://milvus-standalone:19530` |
| `embed_model_id` | ID du modèle d'embedding | `granite-embedding-125m` |
| `max_tokens` | Nombre maximum de tokens par chunk | `512` |
| `use_gpu` | Activer l'accélération GPU | `false` |

### Modèles d'embedding supportés

- `granite-embedding-125m` (IBM Granite)
- Autres modèles SentenceTransformers

## 🔍 Utilisation

### Requête RAG avec LlamaStack

```python
from llama_stack_client import Client, Agent, AgentEventLogger
import uuid

# Connexion au client
client = Client(base_url="http://localhost:8321")

# Créer un agent RAG
rag_agent = Agent(
    client,
    model="llama-32-1b-instruct",
    instructions="Tu es un assistant spécialisé dans l'analyse de documents.",
    tools=[
        {
            "name": "builtin::rag/knowledge_search",
            "args": {"vector_db_ids": ["my_milvus_db"]},
        }
    ],
)

# Créer une session et poser une question
session_id = rag_agent.create_session(session_name=f"session_{uuid.uuid4().hex[:8]}")
response = rag_agent.create_turn(
    messages=[{"role": "user", "content": "Que sais-tu sur les documents analysés ?"}],
    session_id=session_id,
    stream=True,
)

# Afficher la réponse
for log in AgentEventLogger().log(response):
    if hasattr(log, 'content') and log.content:
        print(log.content, end='', flush=True)
```

### Requête directe sur la base vectorielle

```python
# Interroger directement la base vectorielle
query_result = client.vector_io.query(
    vector_db_id="my_milvus_db",
    query="informations importantes",
)

print(f"Résultats trouvés: {len(query_result.results)}")
for result in query_result.results:
    print(f"- {result.content[:100]}...")
```

## 🛠️ Dépannage

### Problèmes courants

1. **PipelineRun échoue :**
   - Vérifier que l'URL des documents est accessible
   - Vérifier les logs du pipeline
   - S'assurer que Milvus est accessible

2. **Test RAG échoue :**
   - Vérifier que LlamaStackDistribution est en phase "Ready"
   - Vérifier l'URL de LlamaStack
   - S'assurer que la base vectorielle contient des données

3. **Erreur de connexion :**
   - Vérifier les routes OpenShift
   - Vérifier les services et pods
   - Contrôler les logs des pods

### Commandes de diagnostic

```bash
# Vérifier les pods
oc get pods -n llama-instruct-32-1b-demo

# Vérifier les services
oc get svc -n llama-instruct-32-1b-demo

# Vérifier les routes
oc get route -n llama-instruct-32-1b-demo

# Logs de LlamaStack
oc logs -l app=llama-stack -n llama-instruct-32-1b-demo

# Logs du pipeline
oc logs pipelinerun/docling-test-run -n llama-instruct-32-1b-demo
```

## 📚 Documentation

- [Red Hat OpenShift AI RAG Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/2.22/html/working_with_rag/deploying-a-rag-stack-in-a-data-science-project_rag)
- [LlamaStack Documentation](https://llama-stack.io/)
- [Docling Documentation](https://github.com/opendatahub-io/docling)

## 🔄 Mise à jour

Pour mettre à jour la configuration RAG :

1. Modifier les fichiers YAML selon vos besoins
2. Appliquer les changements : `oc apply -f .`
3. Redémarrer les ressources si nécessaire
4. Tester avec `python3 test-rag.py`
