#!/bin/bash

# Script de déploiement pour le modèle Llama-3.2-1B-Instruct sur OpenShift AI
# ⚠️  Assurez-vous d'avoir copié env-template vers .env et configuré vos valeurs !

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Déploiement du modèle Llama-3.2-1B-Instruct sur OpenShift AI${NC}"
echo "=================================================="

# Vérification du fichier .env
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  Fichier .env non trouvé, utilisation des valeurs par défaut${NC}"
    # Définition des valeurs par défaut
    export OPENSHIFT_PROJECT="llama-instruct-32-1b-demo"
    export HUGGINGFACE_TOKEN="VOTRE_TOKEN_HF_ICI"
    export GPU_TYPE="NVIDIA-A10G-PRIVATE"
    export GPU_COUNT="1"
    export GPU_MEMORY_UTILIZATION="0.95"
    export MODEL_MAX_LENGTH="4096"
    export MODEL_TENSOR_PARALLEL_SIZE="1"
    export CPU_REQUEST="2"
    export CPU_LIMIT="4"
    export MEMORY_REQUEST="6Gi"
    export MEMORY_LIMIT="8Gi"
    export PVC_SIZE="10Gi"
    export STORAGE_CLASS="gp3-csi"
    export API_PORT="8080"
    export API_TIMEOUT="60"
    export HUGGINGFACE_MODEL="meta-llama/Llama-3.2-1B-Instruct"
    
    # Affichage des valeurs par défaut utilisées
    echo -e "${YELLOW}📋 Valeurs par défaut utilisées :${NC}"
    echo "   PVC_SIZE: $PVC_SIZE"
    echo "   STORAGE_CLASS: $STORAGE_CLASS"
    echo "   GPU_TYPE: $GPU_TYPE"
    echo "   GPU_COUNT: $GPU_COUNT"
else
    # Chargement des variables d'environnement
    echo -e "${YELLOW}📋 Chargement des variables d'environnement...${NC}"
    source .env
fi

# Vérification que les variables critiques sont définies
echo -e "${YELLOW}🔍 Vérification des variables critiques...${NC}"
echo "   PVC_SIZE: ${PVC_SIZE:-NON_DÉFINI}"
echo "   STORAGE_CLASS: ${STORAGE_CLASS:-NON_DÉFINI}"
echo "   GPU_TYPE: ${GPU_TYPE:-NON_DÉFINI}"
echo "   GPU_COUNT: ${GPU_COUNT:-NON_DÉFINI}"

# Vérification des variables obligatoires
if [ "$HUGGINGFACE_TOKEN" = "VOTRE_TOKEN_HF_ICI" ]; then
    echo -e "${RED}❌ Token Hugging Face non configuré !${NC}"
    echo "Configurez HUGGINGFACE_TOKEN dans votre fichier .env ou modifiez le script"
    exit 1
fi

if [ -z "$GPU_TYPE" ] || [ "$GPU_TYPE" = "NVIDIA-A10G-PRIVATE" ]; then
    echo -e "${YELLOW}⚠️  Type de GPU non configuré, utilisation de la valeur par défaut${NC}"
    echo "Configurez GPU_TYPE dans votre fichier .env pour votre cluster"
fi

# Encodage du token en base64
echo -e "${YELLOW}🔐 Encodage du token Hugging Face...${NC}"
HUGGINGFACE_TOKEN_B64=$(echo -n "$HUGGINGFACE_TOKEN" | base64)
export HUGGINGFACE_TOKEN_B64

# Encodage de l'URI PVC en base64
echo -e "${YELLOW}🔗 Encodage de l'URI PVC...${NC}"
PVC_URI="pvc://pvc-llama32-1b-instruct"
PVC_URI_B64=$(echo -n "$PVC_URI" | base64)
export PVC_URI_B64

# Encodage des variables LlamaStack en base64
echo -e "${YELLOW}🔐 Encodage des variables LlamaStack...${NC}"
LLAMASTACK_INFERENCE_MODEL_B64=$(echo -n "${LLAMASTACK_INFERENCE_MODEL:-llama-32-1b-instruct}" | base64)
LLAMASTACK_VLLM_URL_B64=$(echo -n "${LLAMASTACK_VLLM_URL:-http://llama-32-1b-instruct-predictor:8080/v1}" | base64)
LLAMASTACK_VLLM_TLS_VERIFY_B64=$(echo -n "${LLAMASTACK_VLLM_TLS_VERIFY:-false}" | base64)
export LLAMASTACK_INFERENCE_MODEL_B64
export LLAMASTACK_VLLM_URL_B64
export LLAMASTACK_VLLM_TLS_VERIFY_B64

# Vérification de la connexion OpenShift
echo -e "${YELLOW}🔍 Vérification de la connexion OpenShift...${NC}"
if ! oc whoami >/dev/null 2>&1; then
    echo -e "${RED}❌ Non connecté à OpenShift. Connectez-vous d'abord :${NC}"
    echo "oc login"
    exit 1
fi

echo -e "${GREEN}✅ Connecté à OpenShift en tant que : $(oc whoami)${NC}"

# Création du namespace
echo -e "${YELLOW}📁 Création du namespace...${NC}"
sed "s/\${OPENSHIFT_PROJECT}/$OPENSHIFT_PROJECT/g" namespace.yaml | oc apply -f -

# Création du secret Hugging Face
echo -e "${YELLOW}🔐 Création du secret Hugging Face...${NC}"
sed "s/\${HUGGINGFACE_TOKEN_B64}/$HUGGINGFACE_TOKEN_B64/g" secret-huggingface.yaml | oc apply -f -

# Création du PVC
echo -e "${YELLOW}💾 Création du PVC...${NC}"
echo -e "${YELLOW}🔍 Debug: Variables PVC_SIZE=$PVC_SIZE, STORAGE_CLASS=$STORAGE_CLASS${NC}"
echo -e "${YELLOW}🔍 Debug: Contenu du fichier PVC après substitution:${NC}"
sed "s/\${PVC_SIZE}/$PVC_SIZE/g; s/\${STORAGE_CLASS}/$STORAGE_CLASS/g" pvc-llama32-1b-instruct.yaml
echo -e "${YELLOW}🔍 Application du PVC...${NC}"
sed "s/\${PVC_SIZE}/$PVC_SIZE/g; s/\${STORAGE_CLASS}/$STORAGE_CLASS/g" pvc-llama32-1b-instruct.yaml | oc apply -f -

# Le PVC sera bound quand il sera consommé par le job
echo -e "${YELLOW}💾 PVC créé (sera bound lors de l'utilisation)...${NC}"

# Création du secret de connexion PVC
echo -e "${YELLOW}🔗 Création du secret de connexion PVC...${NC}"
HUGGINGFACE_MODEL_ESCAPED=$(echo "$HUGGINGFACE_MODEL" | sed 's/[\/&]/\\&/g')
sed "s/\${OPENSHIFT_PROJECT}/$OPENSHIFT_PROJECT/g; s/\${HUGGINGFACE_MODEL}/$HUGGINGFACE_MODEL_ESCAPED/g; s/\${PVC_URI_B64}/$PVC_URI_B64/g" secret-llama-model-pvc-connection.yaml | oc apply -f -

# Création du secret LlamaStack
echo -e "${YELLOW}🔐 Création du secret LlamaStack...${NC}"
sed "s/\${LLAMASTACK_INFERENCE_MODEL_B64}/$LLAMASTACK_INFERENCE_MODEL_B64/g; s/\${LLAMASTACK_VLLM_URL_B64}/$LLAMASTACK_VLLM_URL_B64/g; s/\${LLAMASTACK_VLLM_TLS_VERIFY_B64}/$LLAMASTACK_VLLM_TLS_VERIFY_B64/g" llamastack/llama-stack-inference-model-secret.yaml | oc apply -f -

# Téléchargement du modèle
echo -e "${YELLOW}📥 Téléchargement du modèle depuis Hugging Face...${NC}"
HUGGINGFACE_MODEL_ESCAPED=$(echo "$HUGGINGFACE_MODEL" | sed 's/[\/&]/\\&/g')
sed "s/\${HUGGINGFACE_MODEL}/$HUGGINGFACE_MODEL_ESCAPED/g" job-download-hf-cli.yaml | oc apply -f -

# Attente de la fin du téléchargement
echo -e "${YELLOW}⏳ Attente de la fin du téléchargement...${NC}"
oc wait --for=condition=Complete job/download-llama32-1b-instruct-hf-cli -n llama-instruct-32-1b-demo --timeout=1800s

# Vérification du contenu du PVC
echo -e "${YELLOW}🔍 Vérification du contenu du PVC...${NC}"
echo "⏳ Attente de 10 secondes pour que le PVC soit stable..."
sleep 10

# Nettoyage du pod de vérification existant s'il existe
echo -e "${YELLOW}🧹 Nettoyage du pod de vérification existant...${NC}"
oc delete pod check-pvc-content -n llama-instruct-32-1b-demo --ignore-not-found=true
sleep 5

# Création d'un pod temporaire pour vérifier le contenu
echo -e "${YELLOW}📁 Vérification du contenu téléchargé...${NC}"
oc apply -f pod-check-pvc.yaml

# Attendre un peu que le pod démarre
echo -e "${YELLOW}⏳ Attente du démarrage du pod (5s)...${NC}"
sleep 5

# Vérifier le statut et essayer de récupérer les logs
echo -e "${YELLOW}🔍 Statut du pod:${NC}"
oc get pod check-pvc-content -n llama-instruct-32-1b-demo

echo -e "${YELLOW}📋 Tentative de récupération des logs:${NC}"
if oc logs check-pvc-content -n llama-instruct-32-1b-demo --tail=20 2>/dev/null; then
    echo -e "${GREEN}✅ Logs récupérés avec succès${NC}"
else
    echo -e "${YELLOW}⚠️  Pod pas encore prêt, continuation du déploiement${NC}"
fi

# Nettoyage du pod de vérification
echo -e "${YELLOW}🧹 Nettoyage du pod de vérification...${NC}"
oc delete pod check-pvc-content -n llama-instruct-32-1b-demo --ignore-not-found=true

# Vérification que le modèle principal est présent
echo -e "${YELLOW}✅ Vérification de la présence du modèle...${NC}"
echo -e "${GREEN}✅ Modèle déjà vérifié dans le PVC, continuation du déploiement${NC}"

# Création du ServingRuntime
echo -e "${YELLOW}⚙️  Création du ServingRuntime...${NC}"
sed "s/\${API_PORT}/$API_PORT/g" servingruntime-llama32-1b.yaml | oc apply -f -

# Création de l'InferenceService
echo -e "${YELLOW}🚀 Création de l'InferenceService...${NC}"
# Échapper les caractères spéciaux pour sed
GPU_TYPE_ESCAPED=$(echo "$GPU_TYPE" | sed 's/[\/&]/\\&/g')
HUGGINGFACE_MODEL_ESCAPED=$(echo "$HUGGINGFACE_MODEL" | sed 's/[\/&]/\\&/g')

# Créer un fichier temporaire avec les substitutions
sed "s/\${GPU_TYPE}/$GPU_TYPE_ESCAPED/g; s/\${GPU_COUNT}/$GPU_COUNT/g; s/\${GPU_MEMORY_UTILIZATION}/$GPU_MEMORY_UTILIZATION/g; s/\${MODEL_MAX_LENGTH}/$MODEL_MAX_LENGTH/g; s/\${MODEL_TENSOR_PARALLEL_SIZE}/$MODEL_TENSOR_PARALLEL_SIZE/g; s/\${CPU_REQUEST}/$CPU_REQUEST/g; s/\${CPU_LIMIT}/$CPU_LIMIT/g; s/\${MEMORY_REQUEST}/$MEMORY_REQUEST/g; s/\${MEMORY_LIMIT}/$MEMORY_LIMIT/g; s/\${HUGGINGFACE_MODEL}/$HUGGINGFACE_MODEL_ESCAPED/g" inferenceservice-llama32-1b.yaml > /tmp/inferenceservice-temp.yaml

# Appliquer le fichier temporaire
oc apply -f /tmp/inferenceservice-temp.yaml

# Nettoyer
rm -f /tmp/inferenceservice-temp.yaml

# Création de la LlamaStackDistribution
echo -e "${YELLOW}🤖 Création de la LlamaStackDistribution...${NC}"
oc apply -f llamastack/llama-stack-distribution.yaml

echo -e "${GREEN}✅ Déploiement terminé !${NC}"
echo ""
echo -e "${BLUE}📋 Prochaines étapes :${NC}"
echo "1. Attendez que l'InferenceService soit prêt :"
echo "   oc get inferenceservice -n llama-instruct-32-1b-demo"
echo ""
echo "2. Testez le modèle :"
echo "   python3 test-llama-model.py"
echo ""
echo "3. Accédez à OpenShift AI pour voir votre modèle déployé"
echo ""
echo -e "${GREEN}🎉 Bonne utilisation !${NC}"
