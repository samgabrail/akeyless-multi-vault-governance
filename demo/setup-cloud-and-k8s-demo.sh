#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-cloud-and-k8s-demo.sh
#
# Seeds the non-Vault demo backends used in the webinar extension:
#   - AWS Secrets Manager
#   - Kubernetes Secrets
#
# It also prepares a Kubernetes service account token suitable for creating
# an Akeyless K8S target and prints export commands for the follow-on
# demo/akeyless-setup.sh step.
# ---------------------------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_DEMO_SECRET_NAME="${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}"
AWS_DEMO_SECRET_VALUE="${AWS_DEMO_SECRET_VALUE:-{\"api_key\":\"aws-demo-payments-key-12345\"}}"

K8S_NAMESPACE="${K8S_NAMESPACE:-mvg-demo}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-payments-config}"
K8S_SERVICE_ACCOUNT="${K8S_SERVICE_ACCOUNT:-akeyless-demo-reader}"
K8S_ROLE_NAME="${K8S_ROLE_NAME:-akeyless-demo-secret-reader}"

echo ""
echo "========================================================"
echo "  Akeyless Demo — AWS + Kubernetes Seed Setup"
echo "========================================================"

AWS_DEMO_READY=false

if command -v aws >/dev/null 2>&1; then
  echo ""
  echo "[1/3] Seeding AWS Secrets Manager secret..."
  if aws sts get-caller-identity --output json >/dev/null 2>&1; then
    if aws secretsmanager describe-secret \
      --region "$AWS_REGION" \
      --secret-id "$AWS_DEMO_SECRET_NAME" >/dev/null 2>&1; then
      aws secretsmanager put-secret-value \
        --region "$AWS_REGION" \
        --secret-id "$AWS_DEMO_SECRET_NAME" \
        --secret-string "$AWS_DEMO_SECRET_VALUE" >/dev/null
      echo "      Updated: $AWS_DEMO_SECRET_NAME ($AWS_REGION)"
    else
      aws secretsmanager create-secret \
        --region "$AWS_REGION" \
        --name "$AWS_DEMO_SECRET_NAME" \
        --secret-string "$AWS_DEMO_SECRET_VALUE" >/dev/null
      echo "      Created: $AWS_DEMO_SECRET_NAME ($AWS_REGION)"
    fi
    AWS_DEMO_READY=true
  else
    echo "      Skipped AWS setup: aws CLI is installed but not authenticated."
  fi
else
  echo ""
  echo "[1/3] Skipped AWS setup: aws CLI not installed."
fi

echo ""
echo "[2/3] Seeding Kubernetes namespace, secret, and reader identity..."
kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE" >/dev/null

kubectl -n "$K8S_NAMESPACE" create secret generic "$K8S_SECRET_NAME" \
  --from-literal=api_key="k8s-demo-payments-key-67890" \
  --from-literal=db_url="postgres://k8s-payments:secret@payments-db.svc.cluster.local:5432/prod" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n "$K8S_NAMESPACE" create serviceaccount "$K8S_SERVICE_ACCOUNT" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $K8S_ROLE_NAME
  namespace: $K8S_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
EOF

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${K8S_ROLE_NAME}-binding
  namespace: $K8S_NAMESPACE
subjects:
- kind: ServiceAccount
  name: $K8S_SERVICE_ACCOUNT
  namespace: $K8S_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: $K8S_ROLE_NAME
EOF

K8S_CLUSTER_ENDPOINT="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')"
K8S_CLUSTER_CA_CERT="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
K8S_CLUSTER_TOKEN="$(kubectl create token "$K8S_SERVICE_ACCOUNT" -n "$K8S_NAMESPACE" --duration=24h)"

echo "      Namespace: $K8S_NAMESPACE"
echo "      Secret   : $K8S_SECRET_NAME"
echo "      Service Account: $K8S_SERVICE_ACCOUNT"

echo ""
echo "[3/3] Export these before running demo/akeyless-setup.sh"
echo ""
echo "export ENABLE_AWS_DEMO=$AWS_DEMO_READY"
echo "export ENABLE_K8S_DEMO=true"
echo "export AWS_REGION='$AWS_REGION'"
echo "export AWS_DEMO_SECRET_NAME='$AWS_DEMO_SECRET_NAME'"
echo "export AWS_USC_PREFIX='demo/mvg/aws/'"
echo "export K8S_NAMESPACE='$K8S_NAMESPACE'"
echo "export K8S_DEMO_SECRET_NAME='$K8S_SECRET_NAME'"
echo "export K8S_CLUSTER_ENDPOINT='$K8S_CLUSTER_ENDPOINT'"
echo "export K8S_CLUSTER_CA_CERT='$K8S_CLUSTER_CA_CERT'"
echo "export K8S_CLUSTER_TOKEN='$K8S_CLUSTER_TOKEN'"
echo ""
echo "If your AWS credentials are not already exported in this shell, also set:"
echo "export AWS_ACCESS_KEY_ID='<your-access-key-id>'"
echo "export AWS_SECRET_ACCESS_KEY='<your-secret-access-key>'"
echo "export AWS_SESSION_TOKEN='<your-session-token>'   # only if using STS creds"
echo ""
