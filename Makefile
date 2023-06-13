# Set the ECR repository name and the image tag
ECR_REPOSITORY_NAME = clinikita
IMAGE_TAG = latest
AWS_DEFAULT_REGION = eu-west-2
ECS_CLUSTER_NAME = clinikita-cluster
ECS_SERVICE_NAME = clinikita-service

help:
	@echo "Makefile to build, push and update services in AWS."

build-and-push: ecr-login webapp-build webapp-push
update: webapp-update


## Login to ECR
ecr-login:
	@aws ecr get-login-password --region $(AWS_DEFAULT_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com

## Build the Docker image
webapp-build:
	@docker build -t $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com/$(ECR_REPOSITORY_NAME):$(IMAGE_TAG) .

## Push the Docker image
webapp-push:
	docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com/$(ECR_REPOSITORY_NAME):$(IMAGE_TAG)

# # Update ECS service
webapp-update:
	aws ecs update-service --cluster $(ECS_CLUSTER_NAME) --service $(ECS_SERVICE_NAME) --force-new-deployment
