<#
This script builds and deploys the Lambda function using the cmdlets provided in the
AWSLambdaPSCore module.

After deployment you must configure a bucket to act as the
source of object created events that will trigger the function to run. You can do
this from inside Visual Studio, if you have the AWS Toolkit for Visual Studio
installed, or from the AWS Management Console's Lambda dashboard.

IMPORTANT
When configuring the event source be sure to specify a key prefix within the bucket
that the event trigger will be scoped to. DO NOT USE THE ROOT! Each time an object
in the bucket is created or updated to a new version, this Lambda function will run.
If you use the root prefix, then you can end up with a runaway set of Lambda
invocations if you configure the function to write a file containing the keywords!
#>

Publish-AWSPowerShellLambda -Name ImageTagger -ScriptPath ./ImageTagger.ps1
