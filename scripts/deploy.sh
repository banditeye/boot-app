#!/usr/bin/env bash

set -u

if [ ! -v AWS_SESSION_TOKEN ]; then
  source ./scripts/switch-role.sh
fi

readonly DOCKER_NAME=micropost/backend
readonly AWS_ACCOUNT_NUMBER=$(aws sts get-caller-identity --output text --query 'Account')
readonly IMAGE_URL=${AWS_ACCOUNT_NUMBER}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${DOCKER_NAME}

# Build
mvn clean package -DskipTests=true -Dmaven.javadoc.skip=true

# Ensure docker repository exists
aws ecr describe-repositories --repository-names ${DOCKER_NAME} > /dev/null 2>&1 || \
  aws ecr create-repository --repository-name ${DOCKER_NAME}

# Download newrelic.jar
wget https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip
unzip newrelic-java.zip
cp newrelic/newrelic.jar docker

# Push to docker repository
eval $(aws ecr get-login)
docker build --build-arg JASYPT_ENCRYPTOR_PASSWORD=${JASYPT_ENCRYPTOR_PASSWORD} -t ${DOCKER_NAME} .
docker tag ${DOCKER_NAME}:latest ${IMAGE_URL}:latest
docker push ${IMAGE_URL}:latest

# Deploy
./scripts/ecs-deploy -c micropost -n backend -i ${IMAGE_URL}:latest
