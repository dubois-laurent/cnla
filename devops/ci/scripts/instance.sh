#!/bin/bash
set -e

REGION="eu-central-1"
export AWS_DEFAULT_REGION=$REGION

AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
    --query 'Parameter.Value' --output text)
KEY_NAME="cnlm-preprod"
KEY_FILE="$HOME/Downloads/${KEY_NAME}.pem"
SUBNET_ID="subnet-0637379b6b2c56632"
SG_ID="sg-0730e05b77b328e25"
IAM_PROFILE="EC2-Readonly-Role"

echo "=== Lancement instance EC2 PREPROD ==="

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_ID" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$IAM_PROFILE" \
    --user-data '#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EC2-PREPROD-cnlm}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "    Instance lancée : $INSTANCE_ID — attente démarrage..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo "=== Résumé — à partager avec l'équipe ==="
echo "    INSTANCE_ID : $INSTANCE_ID"
echo "    PUBLIC_IP   : $PUBLIC_IP"
echo "    REGION      : $REGION"
echo ""
echo "    SSH : ssh -i $KEY_FILE ec2-user@$PUBLIC_IP"
