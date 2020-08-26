# PowerShell script file to be executed as a AWS Lambda function.
#
# When executing in Lambda the following variables will be predefined.
#   $LambdaInput - A PSObject that contains the Lambda function input data.
#   $LambdaContext - An Amazon.Lambda.Core.ILambdaContext object that contains information about the currently running Lambda environment.
#
# The last item in the PowerShell pipeline will be returned as the result of the Lambda function.
#
# To include PowerShell modules with your Lambda function, like the AWSPowerShell.NetCore module, add a "#Requires" statement
# indicating the module and version.
#
# The following link contains documentation describing the structure of the S3 event object.
# https://docs.aws.amazon.com/AmazonS3/latest/dev/notification-content-structure.html

#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='3.3.618.0'}
#Requires -Modules @{ModuleName='AWS.Tools.Comprehend';ModuleVersion='3.3.618.0'}

# Uncomment to send the input event to CloudWatch Logs
Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)

$body = ConvertFrom-Json -InputObject $LambdaInput.body
$text = $body.text

Write-Host $body
Write-Host (ConvertFrom-Json -InputObject $LambdaInput.body)
Write-Host $text

$lang = Find-COMPDominantLanguage -Text $text
Write-Host $lang

$syntax = Find-COMPSyntax -Text $text -LanguageCode $lang.LanguageCode
$words = $syntax | 
    Where-Object { 
    $_.PartOfSpeech.Tag -eq "PROPN" -or 
    $_.PartOfSpeech.Tag -eq "NOUN" 
}  

foreach ($word in $words) {
    $chars = ($word.EndOffset - $word.BeginOffset)
    $text = $text.Remove($word.BeginOffset, $chars)
    $filler = "`u{2588}" * $chars
    $text = $text.Insert($word.BeginOffset, $filler)
}

@{
    'statusCode' = 200;
    'body' = (ConvertTo-Json -InputObject @{redactedText = $text});
    'headers' = @{'Content-Type' = 'application/json'}
}