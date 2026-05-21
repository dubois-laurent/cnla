#!/bin/bash
set -e

REGION="eu-central-1"
export AWS_DEFAULT_REGION=$REGION

AMI_ID=$(aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 \
    --query 'Parameter.Value' --output text)

KEY_NAME="cnlm-preprod"
KEY_FILE="$HOME/Downloads/${KEY_NAME}.pem"
VPC_ID="vpc-0cb9c89e8cdff0e11"
SUBNET_A="subnet-0637379b6b2c56632"   # subnet-pub-cnlm-cam-A
SUBNET_B="subnet-0caf8d63fd3ec8139"   # subnet-pub-cnlm-cam-B
SG_ID="sg-0730e05b77b328e25"
IAM_PROFILE="EC2-CNLA-Profile"

DOCKER_INIT='#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user'

# ── PREPROD ───────────────────────────────────────────────────────────────────

echo "=== Lancement instance EC2 PREPROD ==="

PREPROD_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_A" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$IAM_PROFILE" \
    --user-data "$DOCKER_INIT" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EC2-PREPROD-cnlm}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "    Instance lancée : $PREPROD_ID — attente démarrage..."
aws ec2 wait instance-running --instance-ids "$PREPROD_ID"

PREPROD_IP=$(aws ec2 describe-instances \
    --instance-ids "$PREPROD_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo ""
echo "=== Résumé PREPROD ==="
echo "    INSTANCE_ID : $PREPROD_ID"
echo "    PUBLIC_IP   : $PREPROD_IP"
echo "    SSH         : ssh -i $KEY_FILE ec2-user@$PREPROD_IP"
echo ""

# ── PROD — instances ──────────────────────────────────────────────────────────

echo "=== Lancement instances EC2 PROD (x2) ==="

PROD_1=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_A" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$IAM_PROFILE" \
    --user-data "$DOCKER_INIT" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EC2-PROD-cnlm-1}]" \
    --query 'Instances[0].InstanceId' --output text)

PROD_2=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --key-name "$KEY_NAME" \
    --subnet-id "$SUBNET_B" \
    --security-group-ids "$SG_ID" \
    --iam-instance-profile Name="$IAM_PROFILE" \
    --user-data "$DOCKER_INIT" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=EC2-PROD-cnlm-2}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "    Instance 1 : $PROD_1 (AZ A)"
echo "    Instance 2 : $PROD_2 (AZ B)"
echo "    Attente démarrage..."
aws ec2 wait instance-running --instance-ids "$PROD_1" "$PROD_2"

# ── PROD — Target Group ───────────────────────────────────────────────────────

echo "=== Création du Target Group ==="

TG_ARN=$(aws elbv2 create-target-group \
    --name "prod-target-group" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPC_ID" \
    --health-check-path "/health" \
    --health-check-interval-seconds 30 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

echo "    Target Group : $TG_ARN"

aws elbv2 register-targets \
    --target-group-arn "$TG_ARN" \
    --targets Id="$PROD_1",Port=80 Id="$PROD_2",Port=80

echo "    Instances enregistrées dans le Target Group"

# ── PROD — ALB ────────────────────────────────────────────────────────────────

echo "=== Création de l'ALB ==="

ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "prod-alb" \
    --subnets "$SUBNET_A" "$SUBNET_B" \
    --security-groups "$SG_ID" \
    --scheme internet-facing \
    --type application \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)

echo "    ALB lancé : $ALB_ARN"
echo "    Attente disponibilité ALB..."
aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"

# ── PROD — Listener ───────────────────────────────────────────────────────────

echo "=== Création du Listener HTTP:80 ==="

aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
    > /dev/null

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].DNSName' --output text)

echo ""
echo "=== Résumé PROD ==="
echo "    INSTANCE_1   : $PROD_1 (AZ A — $SUBNET_A)"
echo "    INSTANCE_2   : $PROD_2 (AZ B — $SUBNET_B)"
echo "    TARGET_GROUP : $TG_ARN"
echo "    ALB_ARN      : $ALB_ARN"
echo "    URL PROD     : http://$ALB_DNS"
echo ""
echo "    /!\\ Accès uniquement via l'ALB — ne jamais utiliser les IPs des instances directement"
