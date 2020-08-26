#==============================================================================
# Scans the words in the requested content to determine if any are contained
# in a list of banned content. If any are found, the request is immediately
# rejected.
#
# Input to this function:
#   PSObject with 'requester' and 'content' fields.
#
# Environment parameters to customize this function:
#   none
#
# Parameter Store parameters used by this function:
#   /ContentApprovalWorkflow/UnapprovedWords - string list of unapproved words
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
#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='3.3.618.0'}
#Requires -Modules @{ModuleName='AWS.Tools.SimpleSystemsManagement';ModuleVersion='3.3.618.0'}

$parameterNameRoot = $env:ParameterNameRoot

# Load the unapproved words - in a real world app, we'd perhaps use an online or corporate
# dictionary api. For this demo a comma-delimited list will suffice.
$unapprovedWordList = (Get-SSMParameterValue -Name "$parameterNameRoot/UnapprovedWords").Parameters[0].Value.Split(',')

# not the most efficient but good enough for this demo!
$contentWords = $LambdaInput.content.Split(' ')
foreach ($w in $contentWords) {
    if ($unapprovedWordList.Contains($w)) {
        throw @{
            'Exception'='unapprovedWords'
            'Message'="Unapproved word - $w - found in your content!"
        }
    }
}

$LambdaInput