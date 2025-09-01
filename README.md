# 🚀 Déploiement du modèle Llama-3.2-1B-Instruct sur OpenShift AI

Ce projet permet de déployer le modèle `meta-llama/Llama-3.2-1B-Instruct` sur OpenShift AI en utilisant vLLM comme runtime d'inférence.

## 📋 Prérequis

- **OpenShift CLI** (`oc`) installé et configuré
- **Accès à un cluster OpenShift** avec OpenShift AI installé
- **Token Hugging Face** avec accès au modèle `meta-llama/Llama-3.2-1B-Instruct`
- **GPU disponible** sur le cluster (minimum 1 GPU avec 8GB VRAM)
- **Python 3.8+** et **pip** pour les tests

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenShift                               │
├─────────────────────────────────────────────────────────────┤
│  Secret: huggingface-token                                │
│  PVC: pvc-llama32-1b-instruct                            │
│  └── Modèle téléchargé depuis Hugging Face                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  OpenShift AI                              │
├─────────────────────────────────────────────────────────────┤
│  DataConnection: llama-model-pvc-connection                │
│  ServingRuntime: llama-32-1b-instruct (Serving Model)     │
│  InferenceService: llama-32-1b-instruct                   │
│  └── Pod avec GPU                                         │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Déploiement étape par étape

### 1. Configuration de l'environnement

```bash
# Copier le template d'environnement
cp env-template .env

# Éditer le fichier .env avec vos valeurs
nano .env
```

**Variables obligatoires à configurer :**
- `OPENSHIFT_CLUSTER_URL` : URL de l'API OpenShift
- `OPENSHIFT_CLUSTER_DOMAIN` : Domaine de votre cluster
- `HUGGINGFACE_TOKEN` : Votre token Hugging Face
- `GPU_TYPE` : Type de GPU disponible sur votre cluster

### 2. Connexion à OpenShift

```bash
# Se connecter à votre cluster
oc login $OPENSHIFT_CLUSTER_URL

# Vérifier la connexion
oc whoami
```

### 3. Déploiement manuel étape par étape

Si vous préférez déployer manuellement, voici les commandes à exécuter dans l'ordre :

#### 3.1 Création du namespace

```bash
# Créer le namespace avec les labels OpenShift AI
oc apply -f namespace.yaml
```

#### 3.2 Création du secret Hugging Face

```bash
# Créer le secret avec votre token HF
oc apply -f secret-huggingface.yaml
```

#### 3.3 Création du PVC

```bash
# Créer le PVC pour stocker le modèle
oc apply -f pvc-llama32-1b-instruct.yaml
```

#### 3.4 Création de la connexion PVC

```bash
# Créer la connexion PVC pour OpenShift AI
oc apply -f secret-llama-model-pvc-connection.yaml
```

#### 3.5 Téléchargement du modèle

```bash
# Lancer le job de téléchargement
oc apply -f job-download-hf-cli.yaml

# Attendre la fin du téléchargement
oc wait --for=condition=Complete job/download-llama32-1b-instruct-hf-cli -n llama-instruct-32-1b-demo --timeout=1800s

# Vérifier le contenu du PVC
oc get pvc pvc-llama32-1b-instruct -n llama-instruct-32-1b-demo
```

#### 3.6 Vérification du contenu du PVC

```bash
# Attendre que le PVC soit stable
sleep 10

# Créer un pod temporaire pour vérifier le contenu
oc apply -f pod-check-pvc.yaml

# Attendre que le pod de vérification se termine
oc wait --for=condition=Complete pod/check-pvc-content -n llama-instruct-32-1b-demo --timeout=60s

# Afficher le contenu
oc logs check-pvc-content -n llama-instruct-32-1b-demo

# Nettoyer le pod de vérification
oc delete pod check-pvc-content -n llama-instruct-32-1b-demo --ignore-not-found=true

# Vérifier que le modèle principal est présent
if oc logs check-pvc-content -n llama-instruct-32-1b-demo 2>/dev/null | grep -q "model.safetensors"; then
    echo "✅ Modèle téléchargé avec succès !"
else
    echo "❌ Modèle non trouvé dans le PVC !"
    echo "Vérifiez les logs du job de téléchargement :"
    oc logs job/download-llama32-1b-instruct-hf-cli -n llama-instruct-32-1b-demo
    exit 1
fi
```

#### 3.7 Création du ServingRuntime

```bash
# Créer le runtime vLLM
oc apply -f servingruntime-llama32-1b.yaml
```

#### 3.8 Création de l'InferenceService

```bash
# Créer le service d'inférence
oc apply -f inferenceservice-llama32-1b.yaml

# Attendre que le service soit prêt
oc wait --for=condition=Ready inferenceservice/llama-32-1b-instruct -n llama-instruct-32-1b-demo --timeout=600s
```

### 4. Déploiement automatique

Pour un déploiement automatique et plus simple :

```bash
# Rendre le script exécutable
chmod +x deploy.sh

# Lancer le déploiement complet
./deploy.sh
```

**Ce que fait le script :**
1. ✅ Création du namespace `llama-instruct-32-1b-demo`
2. ✅ Création du secret avec le token Hugging Face
3. ✅ Création du PVC pour stocker le modèle
4. ✅ Création du secret de connexion PVC
5. ✅ Téléchargement du modèle depuis Hugging Face
6. ✅ Vérification du contenu du PVC
7. ✅ Création du ServingRuntime (Serving Model)
8. ✅ Création de l'InferenceService

### 5. Vérification du déploiement

```bash
# Vérifier le statut de l'InferenceService
oc get inferenceservice -n llama-instruct-32-1b-demo

# Vérifier les pods
oc get pods -n llama-instruct-32-1b-demo

# Vérifier le PVC
oc get pvc -n llama-instruct-32-1b-demo

# Vérifier les secrets
oc get secrets -n llama-instruct-32-1b-demo

# Vérifier les événements
oc get events -n llama-instruct-32-1b-demo --sort-by='.lastTimestamp'
```

### 6. Test du modèle

```bash
# Test avec Python
python3 test-llama-model.py

# Test avec curl
./test-llama-curl.sh

# Test manuel avec curl
curl -X POST "https://llama-32-1b-instruct-llama-instruct-32-1b-demo.apps.VOTRE_CLUSTER/v1/models" \
  -H "Content-Type: application/json"
```

## 🗑️ Nettoyage et gestion

### Utilisation du script cleanup.sh

Le script `cleanup.sh` permet de supprimer proprement toutes les ressources créées :

```bash
# Rendre le script exécutable
chmod +x cleanup.sh

# Lancer le nettoyage
./cleanup.sh
```

**Ce que fait le script :**
1. 🔍 Vérification de la connexion OpenShift
2. ⚠️ Demande de confirmation avant suppression
3. 🚫 Suppression de l'InferenceService
4. ⚙️ Suppression du ServingRuntime
5. 📥 Suppression des jobs de téléchargement
6. 🔄 Suppression des pods restants
7. 🔐 Suppression des secrets
8. 💾 Suppression du PVC
9. 📁 Suppression du namespace complet

**⚠️ Attention :** Ce script supprime TOUTES les ressources du projet !

### Nettoyage manuel

Si vous préférez nettoyer manuellement :

```bash
# Supprimer l'InferenceService
oc delete inferenceservice llama-32-1b-instruct -n llama-instruct-32-1b-demo

# Supprimer le ServingRuntime
oc delete servingruntime llama-32-1b-instruct -n llama-instruct-32-1b-demo

# Supprimer les jobs
oc delete job download-llama32-1b-instruct-hf-cli -n llama-instruct-32-1b-demo

# Supprimer les pods
oc delete pods --all -n llama-instruct-32-1b-demo

# Supprimer les secrets
oc delete secret huggingface-token -n llama-instruct-32-1b-demo
oc delete secret llama-model-pvc-connection -n llama-instruct-32-1b-demo

# Supprimer le PVC
oc delete pvc pvc-llama32-1b-instruct -n llama-instruct-32-1b-demo

# Supprimer le namespace (supprime tout le reste)
oc delete namespace llama-instruct-32-1b-demo
```

### Redéploiement

Pour redéployer après un nettoyage :

```bash
# Nettoyer d'abord
./cleanup.sh

# Redéployer
./deploy.sh
```

## 🔧 Configuration détaillée

### Variables d'environnement

| Variable | Description | Exemple |
|----------|-------------|---------|
| `OPENSHIFT_CLUSTER_URL` | URL de l'API OpenShift | `https://api.cluster.example.com:6443` |
| `OPENSHIFT_PROJECT` | Nom du projet/namespace | `llama-instruct-32-1b-demo` |
| `OPENSHIFT_CLUSTER_DOMAIN` | Domaine du cluster | `cluster.example.com` |
| `HUGGINGFACE_TOKEN` | Token d'accès Hugging Face | `hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `HUGGINGFACE_MODEL` | Modèle à télécharger | `meta-llama/Llama-3.2-1B-Instruct` |
| `GPU_TYPE` | Type de GPU | `NVIDIA-A10G-PRIVATE` |
| `GPU_COUNT` | Nombre de GPUs | `1` |
| `GPU_MEMORY_UTILIZATION` | Utilisation mémoire GPU | `0.85` |
| `MODEL_MAX_LENGTH` | Longueur maximale du modèle | `4096` |
| `CPU_REQUEST` | CPU demandé | `2` |
| `CPU_LIMIT` | CPU maximum | `4` |
| `MEMORY_REQUEST` | Mémoire demandée | `6Gi` |
| `MEMORY_LIMIT` | Mémoire maximum | `8Gi` |
| `PVC_SIZE` | Taille du PVC | `10Gi` |
| `STORAGE_CLASS` | Classe de stockage | `gp3-csi` |
| `API_PORT` | Port de l'API | `8080` |

### Ressources créées

- **Namespace** : `llama-instruct-32-1b-demo`
- **PVC** : `pvc-llama32-1b-instruct` (10Gi)
- **Secret** : `huggingface-token` (token HF)
- **Secret** : `llama-model-pvc-connection` (connexion PVC)
- **ServingRuntime** : `llama-32-1b-instruct` (vLLM)
- **InferenceService** : `llama-32-1b-instruct`
- **Job** : `download-llama32-1b-instruct-hf-cli`

## 🧪 Tests

### Test des endpoints

Le modèle expose les endpoints suivants :

### Test de la fonctionnalité RAG (optionnel)

Si vous souhaitez utiliser la fonctionnalité RAG avec Docling :

```bash
# Aller dans le répertoire RAG
cd llamastack/rag

# Déployer la fonctionnalité RAG
./deploy-rag.sh

# Ou déployer manuellement
oc apply -f docling-pipeline.yaml

# Tester la fonctionnalité RAG
python3 test-rag.py
```

Pour plus de détails, consultez le [README RAG](llamastack/rag/README.md).

- **`/v1/models`** : Liste des modèles disponibles
- **`/v1/chat/completions`** : Chat conversationnel
- **`/v1/completions`** : Génération de texte

### Exemple de requête chat

```bash
curl -X POST "https://llama-32-1b-instruct-llama-instruct-32-1b-demo.apps.VOTRE_CLUSTER/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-32-1b-instruct",
    "messages": [
      {"role": "user", "content": "Bonjour, comment allez-vous ?"}
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## 🔍 Dépannage

### Problèmes courants

1. **Token Hugging Face invalide**
   - Vérifiez que votre token a accès au modèle
   - Testez l'accès : `curl -H "Authorization: Bearer $TOKEN" https://huggingface.co/api/models/meta-llama/Llama-3.2-1B-Instruct`

2. **GPU non disponible**
   - Vérifiez les ressources GPU : `oc get nodes -o json | jq '.items[].status.allocatable'`
   - Ajustez `GPU_TYPE` dans `.env`

3. **PVC non bound**
   - Vérifiez la classe de stockage : `oc get storageclass`
   - Ajustez `STORAGE_CLASS` dans `.env`

4. **Modèle non accessible**
   - Vérifiez les logs du pod : `oc logs -f llama-32-1b-instruct-predictor-xxx`
   - Vérifiez que le modèle est téléchargé dans le PVC

### Logs utiles

```bash
# Logs de l'InferenceService
oc logs -f deployment/llama-32-1b-instruct-predictor

# Logs du job de téléchargement
oc logs -f job/download-llama32-1b-instruct-hf-cli

# Événements du namespace
oc get events -n llama-instruct-32-1b-demo
```

## 📚 Ressources

- [Documentation Red Hat OpenShift AI Self-Managed](https://docs.redhat.com/es/documentation/red_hat_openshift_ai_self-managed/2.22)
- [Serving Models - Red Hat OpenShift AI](https://docs.redhat.com/es/documentation/red_hat_openshift_ai_self-managed/2.22/html-single/serving_models/index)
- [Documentation Hugging Face](https://huggingface.co/docs)
- [Modèle Llama-3.2-1B-Instruct](https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct)

## 📁 Structure des fichiers

```
llama-3.2-1B-Instruct-demo/
├── .env                           # Variables d'environnement (à créer)
├── env-template                   # Template des variables
├── .gitignore                     # Fichiers à ignorer par Git
├── README.md                      # Cette documentation
├── deploy.sh                      # Script de déploiement
├── cleanup.sh                     # Script de nettoyage
├── namespace.yaml                 # Configuration du namespace
├── secret-huggingface.yaml        # Secret Hugging Face
├── pvc-llama32-1b-instruct.yaml  # PVC pour le modèle
├── secret-llama-model-pvc-connection.yaml  # Connexion PVC
├── job-download-hf-cli.yaml       # Job de téléchargement
├── servingruntime-llama32-1b.yaml # Runtime vLLM
├── inferenceservice-llama32-1b.yaml # Service d'inférence
├── test-llama-model.py            # Tests Python
├── test-llama-curl.sh             # Tests curl
└── llamastack/                    # Configuration LlamaStack
    ├── llama-stack-inference-model-secret.yaml  # Secret pour LlamaStack
    ├── llama-stack-distribution.yaml            # Distribution LlamaStack
    └── rag/                       # Configuration RAG avec Docling
        ├── README.md              # Documentation RAG
        ├── docling-pipeline.yaml  # Pipeline Tekton pour l'ingestion
        ├── deploy-rag.sh         # Script de déploiement RAG
        └── test-rag.py           # Script de test RAG
```

## 🤝 Contribution

Pour contribuer à ce projet :

1. Fork le repository
2. Créez une branche pour votre fonctionnalité
3. Committez vos changements
4. Poussez vers la branche
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

---

**🎉 Bon déploiement !**
