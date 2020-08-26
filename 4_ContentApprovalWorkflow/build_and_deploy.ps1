<#
his script builds and deploys the three Lambda functions to AWS Lambda to support the
Step Functions workflow using the AWS extensions for the dotnet CLI.

To run this script you need to have installed:
1. the AWSLambdaPSCore module (to build the deployment package)
2. the Amazon.Lambda.Tools global tools package for the dotnet CLI. To install the
tools package run the command 'dotnet tool install -g Amazon.Lambda.Tools' in
a command shell.

The script takes three parameters:
- (mandatory) the user email to which content approve/reject messages should be sent
- (mandatory) the ARN of the deployed sfn-callback-urls function, which is used by the
  workflow to generate links to include an in email for final approval/rejection if
  the submitted content passes automated checks.
- list of words (in leu of a proper dictionary or service) that if found in the
  submitted content will cause it to be automatically rejected

During deployment you will be asked to provide the name of an S3 bucket to
which the deployment bundle can be uploaded. This bucket must exist in the
same region as the Lambda function (us-west-2 is selected by default in the
aws-lambda-tools-defaults.json file).
#>

[CmdletBinding()]
param (

    [Parameter(Mandatory)]
    [string]$CallbackUrlsFunctionArn,

    [Parameter(Mandatory)]
    [string]$ApproverEmail,

    [Parameter]
    [string]$UnapprovedWords

)

New-AWSPowerShellLambdaPackage -ScriptPath ./CheckForUnapprovedWords.ps1 -OutputPackage ./build/CheckForUnapprovedWords.zip
New-AWSPowerShellLambdaPackage -ScriptPath ./Redactor.ps1 -OutputPackage ./build/Redactor.zip
New-AWSPowerShellLambdaPackage -ScriptPath ./SendRequestForApproval.ps1 -OutputPackage ./build/SendRequestForApproval.zip
New-AWSPowerShellLambdaPackage -ScriptPath ./SendDecisionReceipt.ps1 -OutputPackage ./build/SendDecisionReceipt.zip

$templateParameters = "CallbackUrlsFunctionArn=$CallbackUrlsFunctionArn;ApproverEmail=$ApproverEmail"
if ($UnapprovedWords) {
    $templateParameters += ";UnapprovedWords=$UnapprovedWords"
}

dotnet lambda deploy-serverless --template-parameters $templateParameters
