#!/bin/bash

# Configuration - CHANGE THESE
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
REPO_NAME="YOUR_GITHUB_USERNAME/YOUR_REPO_NAME"
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
SERVICE_ACCOUNT_NAME="github-committer-sa"
FUNCTION_NAME="daily-github-commit"
SCHEDULE="0 9 * * *" # Every day at 9:00 AM

echo "🚀 Starting deployment for $FUNCTION_NAME..."

# 1. Enable APIs
echo "✅ Enabling necessary APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  cloudscheduler.googleapis.com \
  iam.googleapis.com

# 2. Create Service Account
echo "👤 Creating service account..."
if ! gcloud iam service-accounts describe ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com > /dev/null 2>&1; then
  gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
    --display-name="GitHub Committer Service Account"
fi

# 3. Deploy Cloud Function (2nd Gen)
echo "📦 Deploying Cloud Function..."
gcloud functions deploy ${FUNCTION_NAME} \
  --gen2 \
  --runtime=python311 \
  --region=${REGION} \
  --source=. \
  --entry-point=daily_commit \
  --trigger-http \
  --no-allow-unauthenticated \
  --service-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
  --set-env-vars GITHUB_TOKEN=${GITHUB_TOKEN},REPO_NAME=${REPO_NAME} \
  --memory=128Mi

# 4. Get Function URL
FUNCTION_URL=$(gcloud functions describe ${FUNCTION_NAME} --region=${REGION} --format='value(url)')

# 5. Create Cloud Scheduler Job
echo "⏰ Creating Cloud Scheduler job..."
# Delete if exists to update
gcloud scheduler jobs delete ${FUNCTION_NAME}-trigger --location=${REGION} --quiet > /dev/null 2>&1

gcloud scheduler jobs create http ${FUNCTION_NAME}-trigger \
  --location=${REGION} \
  --schedule="${SCHEDULE}" \
  --uri="${FUNCTION_URL}" \
  --http-method=GET \
  --oidc-service-account-email=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

echo "✨ Deployment complete!"
echo "Function URL: ${FUNCTION_URL}"
echo "Schedule: ${SCHEDULE}"
echo "--------------------------------------------------"
echo "IMPORTANT: Don't forget to update the GITHUB_TOKEN and REPO_NAME in this script or manually in the GCP Console."
