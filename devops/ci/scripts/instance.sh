#!/bin/bash
set -e

REGION="eu-central-2"
export AWS_DEFAULT_REGION=$REGION

echo "=== Création VPC PREPROD ==="

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.1.0.0/16 --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value=VPC-PREPROD-cnlm
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}'
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support '{"Value":true}'
echo "    VPC créé : $VPC_ID"

echo "=== Création des sous-réseaux ==="

SUBNET_PUB_A=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.1.1.0/24 \
    --availability-zone "${REGION}a" \
    --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PUB_A" --tags Key=Name,Value=subnet-pub-cnlm-A
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUB_A" --map-public-ip-on-launch

SUBNET_PUB_B=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.1.2.0/24 \
    --availability-zone "${REGION}b" \
    --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PUB_B" --tags Key=Name,Value=subnet-pub-cnlm-B
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUB_B" --map-public-ip-on-launch

SUBNET_PRIV_A=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.1.3.0/24 \
    --availability-zone "${REGION}a" \
    --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PRIV_A" --tags Key=Name,Value=subnet-priv-cnlm-A

SUBNET_PRIV_B=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 10.1.4.0/24 \
    --availability-zone "${REGION}b" \
    --query 'Subnet.SubnetId' --output text)
aws ec2 create-tags --resources "$SUBNET_PRIV_B" --tags Key=Name,Value=subnet-priv-cnlm-B
echo "    Sous-réseaux : $SUBNET_PUB_A | $SUBNET_PUB_B | $SUBNET_PRIV_A | $SUBNET_PRIV_B"

echo "=== Création Internet Gateway ==="

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value=IGW-PREPROD-cnlm
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID"
echo "    IGW créée : $IGW_ID"

echo "=== Création NAT Gateway ==="

EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$SUBNET_PUB_A" \
    --allocation-id "$EIP_ALLOC_ID" \
    --query 'NatGateway.NatGatewayId' --output text)
aws ec2 create-tags --resources "$NAT_GW_ID" --tags Key=Name,Value=NAT-PREPROD-cnlm
echo "    NAT Gateway créée : $NAT_GW_ID — attente de disponibilité..."
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NAT_GW_ID"
echo "    NAT Gateway disponible."

echo "=== Tables de routage ==="

RT_PUB_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$RT_PUB_ID" --tags Key=Name,Value=RT-Public-PREPROD
aws ec2 create-route --route-table-id "$RT_PUB_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PUB_A" --route-table-id "$RT_PUB_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PUB_B" --route-table-id "$RT_PUB_ID" > /dev/null

RT_PRIV_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-tags --resources "$RT_PRIV_ID" --tags Key=Name,Value=RT-Private-PREPROD
aws ec2 create-route --route-table-id "$RT_PRIV_ID" --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT_GW_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PRIV_A" --route-table-id "$RT_PRIV_ID" > /dev/null
aws ec2 associate-route-table --subnet-id "$SUBNET_PRIV_B" --route-table-id "$RT_PRIV_ID" > /dev/null
echo "    Tables de routage : $RT_PUB_ID (pub) | $RT_PRIV_ID (priv)"

echo "=== Security Group EC2 PREPROD ==="

SG_EC2_ID=$(aws ec2 create-security-group \
    --group-name SG-EC2-PREPROD-cnlm \
    --description "EC2 PREPROD - SSH, HTTP, HTTPS" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --protocol tcp --port 80 --cidr 0.0.0.0/0 > /dev/null
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_EC2_ID" \
    --protocol tcp --port 443 --cidr 0.0.0.0/0 > /dev/null
echo "    SG créé : $SG_EC2_ID (ports 22, 80, 443)"

echo ""
echo "=== Résumé — à partager avec l'équipe ==="
echo "    VPC_ID          : $VPC_ID"
echo "    SUBNET_PUB_A    : $SUBNET_PUB_A"
echo "    SUBNET_PUB_B    : $SUBNET_PUB_B"
echo "    SUBNET_PRIV_A   : $SUBNET_PRIV_A"
echo "    SUBNET_PRIV_B   : $SUBNET_PRIV_B"
echo "    SG_EC2_ID       : $SG_EC2_ID"
echo "    REGION          : $REGION"
