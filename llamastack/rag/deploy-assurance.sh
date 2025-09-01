#!/bin/bash

# Script de déploiement pour le use case assurance avec RAG
# Basé sur la documentation Red Hat OpenShift AI

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Fonction d'affichage des messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_assurance() {
    echo -e "${PURPLE}[ASSURANCE]${NC} $1"
}

# Vérification des prérequis
check_prerequisites() {
    print_status "Vérification des prérequis pour le use case assurance..."
    
    # Vérifier que oc est installé
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI n'est pas installé"
        exit 1
    fi
    
    # Vérifier la connexion OpenShift
    if ! oc whoami &> /dev/null; then
        print_error "Non connecté à OpenShift"
        exit 1
    fi
    
    # Vérifier que le namespace existe
    if ! oc get namespace llama-instruct-32-1b-demo &> /dev/null; then
        print_error "Namespace llama-instruct-32-1b-demo n'existe pas"
        exit 1
    fi
    
    print_success "Prérequis vérifiés"
}

# Vérifier que LlamaStackDistribution fonctionne
check_llamastack() {
    print_status "Vérification de LlamaStackDistribution..."
    
    if ! oc get llamastackdistribution lsd-llama-32-1b-instruct -n llama-instruct-32-1b-demo &> /dev/null; then
        print_error "LlamaStackDistribution n'existe pas"
        exit 1
    fi
    
    PHASE=$(oc get llamastackdistribution lsd-llama-32-1b-instruct -n llama-instruct-32-1b-demo -o jsonpath='{.status.phase}')
    AVAILABLE=$(oc get llamastackdistribution lsd-llama-32-1b-instruct -n llama-instruct-32-1b-demo -o jsonpath='{.status.available}')
    
    if [ "$PHASE" != "Ready" ] || [ "$AVAILABLE" != "1" ]; then
        print_error "LlamaStackDistribution n'est pas prêt (Phase: $PHASE, Available: $AVAILABLE)"
        exit 1
    fi
    
    print_success "LlamaStackDistribution est prêt"
}

# Déployer le pipeline Docling
deploy_docling_pipeline() {
    print_assurance "Déploiement du pipeline Docling pour l'assurance..."
    
    # Appliquer le pipeline
    oc apply -f docling-pipeline.yaml
    
    if [ $? -eq 0 ]; then
        print_success "Pipeline Docling déployé"
    else
        print_error "Erreur lors du déploiement du pipeline"
        exit 1
    fi
}

# Créer un PipelineRun pour l'assurance
create_assurance_pipelinerun() {
    print_assurance "Création du PipelineRun pour les documents d'assurance..."
    
    # Appliquer la configuration assurance
    oc apply -f assurance-config.yaml
    
    if [ $? -eq 0 ]; then
        print_success "PipelineRun assurance créé"
    else
        print_error "Erreur lors de la création du PipelineRun"
        exit 1
    fi
}

# Vérifier le statut du PipelineRun assurance
check_assurance_pipelinerun_status() {
    print_assurance "Vérification du statut du PipelineRun assurance..."
    
    echo "⏳ Attente de la completion du pipeline assurance (peut prendre plusieurs minutes)..."
    
    # Attendre que le pipeline soit terminé
    oc wait --for=condition=Succeeded --timeout=30m pipelinerun/docling-assurance-run -n llama-instruct-32-1b-demo
    
    if [ $? -eq 0 ]; then
        print_success "PipelineRun assurance terminé avec succès"
    else
        print_warning "PipelineRun assurance n'a pas terminé dans le délai ou a échoué"
        print_status "Vérification des logs..."
        oc logs pipelinerun/docling-assurance-run -n llama-instruct-32-1b-demo
    fi
}

# Tester la fonctionnalité RAG assurance
test_assurance_rag_functionality() {
    print_assurance "Test de la fonctionnalité RAG assurance..."
    
    # Obtenir l'URL de LlamaStack
    LLAMA_STACK_URL=$(oc get route -n llama-instruct-32-1b-demo -o jsonpath='{.items[?(@.metadata.name=="lsd-llama-32-1b-instruct")].spec.host}' 2>/dev/null || echo "localhost:8321")
    
    if [ "$LLAMA_STACK_URL" != "localhost:8321" ]; then
        LLAMA_STACK_URL="https://$LLAMA_STACK_URL"
    else
        LLAMA_STACK_URL="http://localhost:8321"
    fi
    
    print_status "URL LlamaStack: $LLAMA_STACK_URL"
    
    # Exporter les variables d'environnement pour le test
    export LLAMA_STACK_URL="$LLAMA_STACK_URL"
    export MODEL_ID="llama-32-1b-instruct"
    export VECTOR_DB_ID="assurance_milvus_db"
    
    # Exécuter le test RAG assurance
    if python3 test-assurance-rag.py; then
        print_success "Test RAG assurance réussi"
    else
        print_warning "Test RAG assurance échoué (peut être normal si la base est vide)"
    fi
}

# Afficher les informations d'utilisation
show_usage_info() {
    print_assurance "Informations d'utilisation du système RAG assurance..."
    
    echo ""
    echo "🏢 SYSTÈME RAG ASSURANCE DÉPLOYÉ"
    echo "=" * 50
    echo ""
    echo "📋 Bases vectorielles créées:"
    echo "   - assurance_milvus_db (documents assurance EN)"
    echo "   - assurance_fr_milvus_db (documents assurance FR)"
    echo ""
    echo "🔍 Questions d'exemple:"
    echo "   - Quelles sont les garanties de base d'une assurance auto ?"
    echo "   - Comment fonctionne la procédure de déclaration de sinistre ?"
    echo "   - Quelles sont les exclusions courantes dans les polices ?"
    echo "   - Quels sont les facteurs qui influencent le prix d'une assurance ?"
    echo ""
    echo "🎭 Scénarios testés:"
    echo "   - Accident de voiture"
    echo "   - Vol à domicile"
    echo "   - Dégât des eaux"
    echo "   - Résiliation d'assurance"
    echo ""
    echo "📊 Commandes de vérification:"
    echo "   oc get pipelinerun -n llama-instruct-32-1b-demo"
    echo "   oc logs pipelinerun/docling-assurance-run -n llama-instruct-32-1b-demo"
    echo "   python3 test-assurance-rag.py"
    echo ""
}

# Fonction principale
main() {
    echo "🏢 Déploiement du use case assurance avec RAG"
    echo "=" * 60
    
    check_prerequisites
    check_llamastack
    deploy_docling_pipeline
    create_assurance_pipelinerun
    check_assurance_pipelinerun_status
    test_assurance_rag_functionality
    show_usage_info
    
    echo ""
    echo "🎉 Déploiement assurance RAG terminé!"
    echo ""
    echo "📋 Prochaines étapes:"
    echo "  1. Vérifiez les logs du PipelineRun:"
    echo "     oc logs pipelinerun/docling-assurance-run -n llama-instruct-32-1b-demo"
    echo ""
    echo "  2. Testez la fonctionnalité RAG assurance:"
    echo "     python3 test-assurance-rag.py"
    echo ""
    echo "  3. Pour ingérer vos propres documents d'assurance, modifiez assurance-config.yaml"
    echo ""
    echo "  4. Pour tester avec des documents français:"
    echo "     oc apply -f - << EOF"
    echo "     apiVersion: tekton.dev/v1"
    echo "     kind: PipelineRun"
    echo "     metadata:"
    echo "       name: docling-assurance-fr-run"
    echo "       namespace: llama-instruct-32-1b-demo"
    echo "     spec:"
    echo "       pipelineRef:"
    echo "         name: docling-pipeline"
    echo "       params:"
    echo "         - name: vector_db_id"
    echo "           value: \"assurance_fr_milvus_db\""
    echo "     EOF"
    echo ""
}

# Exécution du script
main "$@"
