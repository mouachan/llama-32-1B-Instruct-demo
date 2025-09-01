#!/bin/bash

# Script de nettoyage pour le modèle Llama-3.2-1B-Instruct sur OpenShift AI
# ⚠️  Ce script supprime TOUTES les ressources créées !

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  NETTOYAGE COMPLET du modèle Llama-3.2-1B-Instruct${NC}"
echo "=================================================="

# Définition des valeurs par défaut
DEFAULT_PROJECT="llama-instruct-32-1b-demo"

# Chargement des variables d'environnement si le fichier .env existe
if [ -f .env ]; then
    echo -e "${YELLOW}📋 Chargement des variables d'environnement...${NC}"
    source .env
    PROJECT_NAME="${OPENSHIFT_PROJECT:-$DEFAULT_PROJECT}"
else
    echo -e "${YELLOW}⚠️  Fichier .env non trouvé, utilisation des valeurs par défaut${NC}"
    PROJECT_NAME="$DEFAULT_PROJECT"
fi

# Vérification de la connexion OpenShift
echo -e "${YELLOW}🔍 Vérification de la connexion OpenShift...${NC}"
if ! oc whoami >/dev/null 2>&1; then
    echo -e "${RED}❌ Non connecté à OpenShift. Connectez-vous d'abord :${NC}"
    echo "oc login"
    exit 1
fi

echo -e "${GREEN}✅ Connecté à OpenShift en tant que : $(oc whoami)${NC}"

# Confirmation de suppression
echo -e "${RED}⚠️  ATTENTION : Ce script va supprimer TOUTES les ressources suivantes :${NC}"
echo "   - Namespace : $PROJECT_NAME"
echo "   - PVC : pvc-llama32-1b-instruct"
echo "   - Secrets : huggingface-token, llama-model-pvc-connection, llama-stack-inference-model-secret"
echo "   - ServingRuntime : llama-32-1b-instruct"
echo "   - InferenceService : llama-32-1b-instruct"
echo "   - LlamaStackDistribution : lsd-llama-32-1b-instruct"
echo "   - Jobs de téléchargement"
echo "   - Tous les pods associés"
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (oui/non): " confirm

if [ "$confirm" != "oui" ]; then
    echo -e "${YELLOW}❌ Nettoyage annulé${NC}"
    exit 0
fi

echo -e "${YELLOW}🗑️  Début du nettoyage...${NC}"

# Suppression de la LlamaStackDistribution
echo -e "${YELLOW}🤖 Suppression de la LlamaStackDistribution...${NC}"
oc delete llamastackdistribution lsd-llama-32-1b-instruct -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression de l'InferenceService
echo -e "${YELLOW}🚫 Suppression de l'InferenceService...${NC}"
oc delete inferenceservice llama-32-1b-instruct -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression du ServingRuntime
echo -e "${YELLOW}⚙️  Suppression du ServingRuntime...${NC}"
oc delete servingruntime llama-32-1b-instruct -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression des jobs de téléchargement
echo -e "${YELLOW}📥 Suppression des jobs de téléchargement...${NC}"
oc delete job download-llama32-1b-instruct-hf-cli -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression des pods restants
echo -e "${YELLOW}🔄 Suppression des pods restants...${NC}"
oc delete pods --all -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression des secrets
echo -e "${YELLOW}🔐 Suppression des secrets...${NC}"
oc delete secret huggingface-token -n "$PROJECT_NAME" --ignore-not-found=true
oc delete secret llama-model-pvc-connection -n "$PROJECT_NAME" --ignore-not-found=true
oc delete secret llama-stack-inference-model-secret -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression du PVC
echo -e "${YELLOW}💾 Suppression du PVC...${NC}"
oc delete pvc pvc-llama32-1b-instruct -n "$PROJECT_NAME" --ignore-not-found=true

# Suppression du namespace (supprime tout le reste)
echo -e "${YELLOW}📁 Suppression du namespace...${NC}"
oc delete namespace "$PROJECT_NAME" --ignore-not-found=true

echo -e "${GREEN}✅ Nettoyage terminé !${NC}"
echo ""
echo -e "${BLUE}📋 Ressources supprimées :${NC}"
echo "   ✅ LlamaStackDistribution"
echo "   ✅ InferenceService"
echo "   ✅ ServingRuntime"
echo "   ✅ Jobs de téléchargement"
echo "   ✅ Pods"
echo "   ✅ Secrets"
echo "   ✅ PVC"
echo "   ✅ Namespace complet"
echo ""
echo -e "${GREEN}🎉 Toutes les ressources ont été supprimées avec succès !${NC}"
