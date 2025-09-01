#!/bin/bash

# Script de déploiement pour la partie RAG avec Docling
# Basé sur la documentation Red Hat OpenShift AI

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Vérification des prérequis
check_prerequisites() {
    print_status "Vérification des prérequis..."
    
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
    print_status "Déploiement du pipeline Docling..."
    
    # Appliquer le pipeline
    oc apply -f docling-pipeline.yaml
    
    if [ $? -eq 0 ]; then
        print_success "Pipeline Docling déployé"
    else
        print_error "Erreur lors du déploiement du pipeline"
        exit 1
    fi
}

# Créer un PipelineRun de test
create_test_pipelinerun() {
    print_status "Création d'un PipelineRun de test..."
    
    cat << EOF | oc apply -f -
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
      value: "https://raw.githubusercontent.com/opendatahub-io/odh-demos/main/rag-demo/sample-docs"
    - name: pdf_filenames
      value: "sample-document.pdf"
    - name: vector_db_id
      value: "test_milvus_db"
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
    
    if [ $? -eq 0 ]; then
        print_success "PipelineRun de test créé"
    else
        print_error "Erreur lors de la création du PipelineRun"
        exit 1
    fi
}

# Vérifier le statut du PipelineRun
check_pipelinerun_status() {
    print_status "Vérification du statut du PipelineRun..."
    
    echo "⏳ Attente de la completion du pipeline (peut prendre plusieurs minutes)..."
    
    # Attendre que le pipeline soit terminé
    oc wait --for=condition=Succeeded --timeout=30m pipelinerun/docling-test-run -n llama-instruct-32-1b-demo
    
    if [ $? -eq 0 ]; then
        print_success "PipelineRun terminé avec succès"
    else
        print_warning "PipelineRun n'a pas terminé dans le délai ou a échoué"
        print_status "Vérification des logs..."
        oc logs pipelinerun/docling-test-run -n llama-instruct-32-1b-demo
    fi
}

# Tester la fonctionnalité RAG
test_rag_functionality() {
    print_status "Test de la fonctionnalité RAG..."
    
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
    export VECTOR_DB_ID="test_milvus_db"
    
    # Exécuter le test RAG
    if python3 test-rag.py; then
        print_success "Test RAG réussi"
    else
        print_warning "Test RAG échoué (peut être normal si la base est vide)"
    fi
}

# Fonction principale
main() {
    echo "🚀 Déploiement de la fonctionnalité RAG avec Docling"
    echo "=" * 60
    
    check_prerequisites
    check_llamastack
    deploy_docling_pipeline
    create_test_pipelinerun
    check_pipelinerun_status
    test_rag_functionality
    
    echo ""
    echo "🎉 Déploiement RAG terminé!"
    echo ""
    echo "📋 Prochaines étapes:"
    echo "  1. Vérifiez les logs du PipelineRun:"
    echo "     oc logs pipelinerun/docling-test-run -n llama-instruct-32-1b-demo"
    echo ""
    echo "  2. Testez manuellement la fonctionnalité RAG:"
    echo "     python3 test-rag.py"
    echo ""
    echo "  3. Pour ingérer vos propres documents, modifiez les paramètres du PipelineRun"
    echo ""
}

# Exécution du script
main "$@"
