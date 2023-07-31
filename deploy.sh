#!/bin/bash
if [ $# -ne 4 ]; then
    echo "Enter the StackName,Region,TemplateName and Parameters file Name as arguments while executing"
    exit 0
else
    StackName=$1
    Region=$2
    TemplateName=$3
    ParametersFilename=$4
fi
aws cloudformation create-stack --stack-name ${StackName} --template-body file://${TemplateName} --parameters file://${ParametersFilename} --region ${Region} --capabilities CAPABILITY_NAMED_IAM 
EXIT_STATUS=$?
if [ "$EXIT_STATUS" -eq "0" ] 
then
  aws cloudformation describe-stack-events \
        --stack-name $1 \
        --region $2 \
        --output text \
        --query "StackEvents[*].[ResourceStatus,LogicalResourceId,ResourceType,Timestamp]" | 
  sort -k4 |
  column -t
  aws cloudformation wait stack-create-complete --stack-name ${StackName} --region ${Region}
  aws cloudformation describe-stack-events \
        --stack-name $1 \
        --region $2 \
        --output text \
        --query "StackEvents[*].[ResourceStatus,LogicalResourceId,ResourceType,Timestamp]" | 
  sort -k4 |
  column -t
elif [ "$EXIT_STATUS" -eq "252" ]
then
  echo "Please enter Template Name, Parameter File Name, Region Name Properly"  
else 
echo "Stack Already Exists"
### Initiate drift detection
DRIFT_DETECTION_ID=$(aws cloudformation detect-stack-drift --stack-name ${StackName} --region ${Region} --query StackDriftDetectionId --output text)

### Wait for detection to complete
echo -n "Waiting for Root Stack drift detection to complete..."
while true; do
    DETECTION_STATUS=$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id ${DRIFT_DETECTION_ID} --region ${Region} --query DetectionStatus --output text)
    if [ "DETECTION_IN_PROGRESS" = "${DETECTION_STATUS}" ]; then
        echo -n "."
        sleep 3
    elif [ "DETECTION_FAILED" = "${DETECTION_STATUS}" ]; then
        DETECTION_STATUS_REASON=$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id ${DRIFT_DETECTION_ID} --region ${Region} --query DetectionStatusReason --output text)
        STACK_DRIFT_STATUS=$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id ${DRIFT_DETECTION_ID} --region ${Region} --query StackDriftStatus --output text)
        echo ${STACK_DRIFT_STATUS}
        echo "WARNING: ${DETECTION_STATUS_REASON}"
        break
    else
        STACK_DRIFT_STATUS=$(aws cloudformation describe-stack-drift-detection-status --stack-drift-detection-id ${DRIFT_DETECTION_ID} --region ${Region} --query StackDriftStatus --output text)
        echo ${STACK_DRIFT_STATUS}
        break
    fi
done

### Describe the drift details
if [ "DRIFTED" = "${STACK_DRIFT_STATUS}" ]; then
    echo "${StackName} Stack has been drifted. Please Check...!"
else
    echo "${StackName} Stack has not been drifted."
    echo "${StackName} Creating the Change Set"
    Change_Set=$(aws cloudformation deploy --stack-name ${StackName} --template-file ${TemplateName} --parameter-overrides file://${ParametersFilename} --capabilities CAPABILITY_NAMED_IAM --region ${Region} --no-execute-changeset | tail -1)
    aws ses send-email --from manoj.m@axcess.io --destination ToAddresses=darshan.s@axcess.io,CcAddresses=manoj.m@axcess.io --text "Changeset have been created for the ${StackName} Stack. Please verify the changes and execute the Change set." --subject "Cloudformation Change Set Approval"

    # aws cloudformation update-stack --stack-name ${StackName} --template-body file://${TemplateName} --parameters file://${ParametersFilename} --region ${Region} --capabilities CAPABILITY_NAMED_IAM
    # aws cloudformation describe-stack-events \
    #       --stack-name $1 \
    #       --region $2 \
    #       --output text \
    #       --query "StackEvents[*].[ResourceStatus,LogicalResourceId,ResourceType,Timestamp]" | 
    # sort -k4 |
    # column -t
    # aws cloudformation wait stack-update-complete --stack-name ${StackName} --region ${Region}
    # aws cloudformation describe-stack-events \
    #       --stack-name $1 \
    #       --region $2 \
    #       --output text \
    #       --query "StackEvents[*].[ResourceStatus,LogicalResourceId,ResourceType,Timestamp]"| 
    # sort -k4 |
    # column -t      
fi
fi