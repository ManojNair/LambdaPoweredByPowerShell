#==============================================================================
# Triggered when the workflow resumes after the approver has clicked the approve
# or reject links from the previous email. Sends a confirmation email to the
# approver of their actions. It is assumed a separate Lambda, or maybe even this
# one, could be added to notify the requester of the decision.
#
# Input to this function:
#   PSObject with 'requester' and 'content' fields.
#
# Environment parameters to customize this function:
#   none
#
# Parameter Store parameters used by this function:
#   /ContentApprovalWorkflow/EmailTopicArn
#       the SNS topic arn to which the confirmation will be sent. We assume
#       the requester is also subscribed to this topic to keep the demo simple!
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
#Requires -Modules AWS.Tools.Common,AWS.Tools.SimpleSystemsManagement,AWS.Tools.SimpleNotificationService

$parameterNameRoot = $env:ParameterNameRoot

$topicArn = (Get-SSMParameterValue -Name "$parameterNameRoot/EmailTopicArn").Parameters[0].Value

# Compose email
if ($LambdaInput.errorInfo) {
    # request was rejected by automated inspection, the Cause member is a json
    # payload
    $cause = $LambdaInput.errorInfo.cause | ConvertFrom-Json

    $email_subject = 'Automated content inspection failed'
    $email_body = @"
    Hello,

    The request from $($LambdaInput.requester) to publish the content below:

        $($LambdaInput.content)

    was rejected because:

        $($cause.errorMessage)

    Please advise the submitter to edit their post and resubmit. Thank you!
"@
} elseif ($LambdaInput.output.Error) {
    # the approver clicked the rejection link
    $email_subject = 'Content publish request rejected'
    $email_body = @"
        Hello,

        You rejected the request from $($LambdaInput.requester) to publish the content below:

            $($LambdaInput.content)

        because:

            $($LambdaInput.output.cause)

        Please advise the submitter to edit their post and resubmit. Thank you!
"@
} else {
    # the approver clicked the approval link
    $email_subject = 'Content publish request approved'
    $email_body = @"
        Hello,

        You approved the request from $($LambdaInput.requester) to publish the content below:

        $($LambdaInput.content)

"@
}

$publishArgs = @{
    TopicArn = $topicArn
    Subject = $email_subject
    Message = $email_body
}

Write-Host "Sending confirmation email to $topicArn"
Publish-SNSMessage @publishArgs
