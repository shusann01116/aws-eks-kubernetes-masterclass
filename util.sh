#!/bin/bash

set -uexo pipefail

CLUSTER_NAME=eksdemo1
NODEGROUP_NAME=${CLUSTER_NAME}-ng-public1
SSH_KEY_NAME=kube-demo3
REGION=ap-northeast-1
PROFILE=sandbox
ACCOUNT_ID=$(aws sts get-caller-identity --profile ${PROFILE} | jq '.Account' -r) # Assume the profile has granted a credential to access

function start() {
    eksctl create cluster \
        --profile=${PROFILE} \
        --name=${CLUSTER_NAME} \
        --region=${REGION} \
        --without-nodegroup

    eksctl utils associate-iam-oidc-provider \
        --profile=${PROFILE} \
        --region ${REGION} \
        --cluster ${CLUSTER_NAME} \
        --approve

    eksctl create nodegroup \
        --profile=${PROFILE} \
        --cluster=${CLUSTER_NAME} \
        --region=${REGION} \
        --name=${NODEGROUP_NAME} \
        --node-type=t3.medium \
        --nodes=2 \
        --nodes-min=2 \
        --nodes-max=4 \
        --node-volume-size=20 \
        --ssh-access \
        --ssh-public-key=${SSH_KEY_NAME} \
        --managed \
        --asg-access \
        --external-dns-access \
        --full-ecr-access \
        --appmesh-access \
        --alb-ingress-access

    eksctl create iamserviceaccount \
        --profile=${PROFILE} \
        --region ${REGION} \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster eksdemo1 \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve \
        --role-only \
        --role-name AmazonEKS_EBS_CSI_DriverRole

    eksctl create addon \
        --profile=${PROFILE} \
        --region ${REGION} \
        --name aws-ebs-csi-driver \
        --cluster eksdemo1 \
        --service-account-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole" \
        --force
}

function stop() {
    eksctl delete cluster \
        --profile=${PROFILE} \
        --name ${CLUSTER_NAME}
}

$1
