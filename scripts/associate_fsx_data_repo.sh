STACK_NAME="${1}"
REGION="us-east-1"
S3_BUCKET="sandbox-imgaging-bucket-output"

export FSX_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='FSXIds'].OutputValue" --output text)

aws fsx create-data-repository-association \
 --file-system-id $FSX_ID \
 --file-system-path "/$S3_BUCKET" \
 --data-repository-path "s3://$S3_BUCKET" \
 --batch-import-meta-data-on-create \
 --s3 'AutoImportPolicy={Events=["NEW","CHANGED","DELETED"]},AutoExportPolicy={Events=["NEW","CHANGED","DELETED"]}'