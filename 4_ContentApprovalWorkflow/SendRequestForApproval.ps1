#==============================================================================
# Constructs the callback urls for manual approval/rejection of the proposed
# content, then publishes a message to a defined SNS topic triggering the email
# to subscribers. The callback urls are generated by calling another Lambda
# function based on the sfn-callback-urls application that can be found in
# the AWS Serverless Application Repository.
#
# Input to this function:
#   PSObject with 'requester' and 'content' fields.
#
# Environment parameters to customize this function:
#   none
#
# Parameter Store parameters used by this function:
#   /ContentApprovalWorkflow/EmailTopicArn
#       the SNS topic arn to which the approve/reject notification will be sent
#   /ContentApprovalWorkflow/CallbackUrlsFunctionArn
#       the arn of the deployed sfn-callback-urls Lambda function to call to
#       generate the callback urls.
#
#=============================================================================

# When executing in Lambda the following variables will be predefined.
#   $LambdaInput        A PSObject that contains the Lambda function input data.
#   $LambdaContext      An Amazon.Lambda.Core.ILambdaContext object that contains
#                       information about the currently running Lambda environment.
#
# The last item in the PowerShell pipeline will be returned as the result of the
# Lambda function.

# Note: we're using the new preview release of the AWS Tools for PowerShell here.
# The Lambda tooling doesn't currently follow the dependency chain so we have to be
# explicit and add the common module.
#Requires -Modules AWS.Tools.Common,AWS.Tools.SimpleSystemsManagement,AWS.Tools.SimpleNotificationService,AWS.Tools.Lambda

$parameterNameRoot = $env:ParameterNameRoot

$topicArn = (Get-SSMParameterValue -Name "$parameterNameRoot/EmailTopicArn").Parameters[0].Value
$callbackUrlFunction = (Get-SSMParameterValue -Name "$parameterNameRoot/CallbackUrlsFunctionArn").Parameters[0].Value

Write-Host "Received request to approve content '$($LambdaInput.content)' for user $($LambdaInput.requester)"

$sfnCallbackUrlInput = @{
    # Step Functions gives us this callback token
    # sfn-callback-urls needs it to be able to complete the task
    'token'="$($LambdaInput.Token)"
    'actions'=@(
        # The approval action that transfers the name to the output
        @{
            'name'='approve'
            'type'='success'
            'output'="$($LambdaInput.requestor), your request was approved."
        },
        @{
            'name'='reject'
            'type'='failure'
            'error'='rejected'
            'cause'="$($LambdaInput.requester), please rework your content and and resubmit your request."
        }
    )
}

$payload = $sfnCallbackUrlInput | ConvertTo-Json -Compress
Write-Host "Sending payload $payload to sfn-callback-urls function"

$response = Invoke-LMFunction -FunctionName $callbackUrlFunction -Payload $payload
$StreamReader = [System.IO.StreamReader]::new($response.Payload)
$data = $StreamReader.ReadToEnd() | ConvertFrom-Json

Write-Host "Received urls $($data.urls)"

# Compose email
$email_subject = 'Content workflow example approve/reject request'

$email_body = @"
    Hello content approver overlord!

    $($LambdaInput.requester) has requested approval to post the following content:

        $($LambdaInput.content)

    Click below to approve or reject the proposed content for publication:

    Approve:
    $($data.urls.approve)

    Reject:
    $($data.urls.reject)
"@

$publishArgs = @{
    TopicArn = $topicArn
    Subject = $email_subject
    Message = $email_body
}

Write-Host "Sending notification email for approval/rejection to $topicArn"
Publish-SNSMessage @publishArgs
