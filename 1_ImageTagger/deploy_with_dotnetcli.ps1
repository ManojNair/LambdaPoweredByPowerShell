<#
This script builds and deploys the ImageTagger function to AWS Lambda using the
AWS extensions for the dotnet CLI.

To run this script you need to have installed:
1. the AWSLambdaPSCore module (to build the deployment package)
2. the Amazon.Lambda.Tools global tools package for the dotnet CLI. To install the
tools package run the command 'dotnet tool install -g Amazon.Lambda.Tools' in
a command shell.

The Lambda function to deploy is defined in the serverless.template file. In
addition the template creates a new S3 bucket that will be bound to trigger the
Lambda function to run when objects are created or updated under a specified
key prefix. By default that key prefix is 'images' but it can be changed by
supplying a value to this script fo the InputImagesPrefix parameter.

During deployment you will be asked to provide the name of an S3 bucket to
which the deployment bundle can be uploaded. This bucket must exist in the
same region as the Lambda function (us-west-2 is selected by default in the
aws-lambda-tools-defaults.json file).
#>

param (
    # The Lambda function will be triggered when new objects are created, or
    # existing objects updated, that have this key prefix (path) in the bucket.
    # The default value here matches that in the serverless.template file.
    [string]$InputImagesPrefix = "images"
)

# First build the deployment bundle containing our code, bootstrap files
# and supporting modules that our code invokes (see the 'requires' statements in
# the function code
New-AWSPowerShellLambdaPackage -ScriptPath ./ImageTagger.ps1 -OutputPackage ./build/ImageTagger.zip

# Now deploy the bundle and create/update the Lambda function. Settings in the
# provided aws-lambda-tools-defaults.json file provide inputs to the command line,
# to override simply use the relevant command line switches (use dotnet lambda deploy-serverless help
# to see the collection of switches).
# You will be asked to provide the name of an Amazon S3 bucket to which the deployment
# bundle can be uploaded - it must exist in the same region as the intended Lambda
# function.
# The InputImagesPrefix value supplied here will override the default value set for
# the parameter in the serverless.template file.
dotnet lambda deploy-serverless --template-parameters "InputImagesPrefix=$InputImagesPrefix"
