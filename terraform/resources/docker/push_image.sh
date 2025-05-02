#!/bin/bash

set -e

usage() {
  echo "Usage: $0 --region <region> --repo <repo_name> [--tag <tag>]"
  exit 1
}

TAG="latest"

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --region) REGION="$2"; shift ;;
    --repo) REPO_NAME="$2"; shift ;;
    --tag) TAG="$2"; shift ;;
    *) echo "Unknown input: $1"; usage ;;
  esac
  shift
done

if [[ -z "$REGION" || -z "$REPO_NAME" ]]; then
  echo "Error: --region or --repo are missing"
  usage
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}"

echo "Building Docker image..."
docker build -t ${REPO_NAME}:${TAG} .

echo "Logging in to ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REPO_URL}

echo "Tagging image as ${REPO_URL}:${TAG}..."
docker tag ${REPO_NAME}:${TAG} ${REPO_URL}:${TAG}


echo "Pushing image to ECR..."
docker push ${REPO_URL}:${TAG}

echo "Done! Image pushed to: ${REPO_URL}:${TAG}"
