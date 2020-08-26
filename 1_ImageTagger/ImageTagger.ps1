#==============================================================================
# Environment variables to customize this function:
#  MinConfidence       Sets the minimum confidence level for label detection in
#                      Amazon Rekognition. If not specified a default of 70% is
#                      used.
#  OutputStyle         Set to 'file' to have the detected labels (keywords) written
#                      as a file to the bucket
#  OutputFilePrefix    Read if OutputStyle is set to 'file', allows customization
#                      of the output path of the keyword files. If not specified
#                      '/keywords' is used by default.
#==============================================================================

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
#Requires -Modules @{ModuleName='AWS.Tools.S3';ModuleVersion='3.3.618.0'}
#Requires -Modules @{ModuleName='AWS.Tools.Rekognition';ModuleVersion='3.3.618.0'}

# Uncomment to send the input event to CloudWatch Logs
# Write-Host (ConvertTo-Json -InputObject $LambdaInput -Compress -Depth 5)

$imageExtensions = @(".jpg",".jpeg",".png",".gif")

# we're allowed a max of 10 if applying as tags to an S3 object
$maxTags = 10
$defaultConfidence = 70

$outputAsTags = $true

# if we're outputting the results to a file, be sure to not to write to the
# same key prefix as triggers the Lambda otherwise endless runaway loop!
$outputFilePrefix = '/keywords'
$outputStyle = $env:OutputStyle
if ($outputStyle -eq 'file') {
    $outputAsTags = $false

    if ($env:OutputFilePrefix) {
        $outputFilePrefix = $env:OutputFilePrefix
    }

    Write-Host "$outputStyle output style set, tag files will be written to $outputFilePrefix path"
}

$confidence = $env:MinConfidence
if ($confidence) {
    Write-Host "MinConfidence environment variable set to $confidence%"
} else {
    Write-Host "MinConfidence environment variable not set, defaulting to $defaultConfidence%"
    $confidence = $defaultConfidence
}

foreach ($record in $LambdaInput.Records) {
    $bucket = $record.s3.bucket.name
    $key = $record.s3.object.key

    Write-Host "Processing event for: bucket = $bucket, key = $key"

    $ext = [System.IO.Path]::GetExtension($key)
    if ($imageExtensions.Contains($ext)) {

        Write-Host "Inspecting for labels with confidence equal or higher than $confidence%"
        $labels = (Find-REKLabel -ImageBucket $bucket -ImageName $key -MinConfidence $confidence).Labels
        Write-Host "Rekognition detected $($labels.Count) labels"

        if ($outputAsTags -And $labels.Count -gt $maxTags) {
            Write-Host "Reducing detected labels to $maxTags before applying as S3 object tags"
            $labels = $labels | Select-Object -First $maxTags
        }

        if ($outputAsTags) {
            Write-Host "Posting $($labels.Count) labels to the S3 object as tags"

            $tags = @()
            $labels | ForEach-Object {

                Write-Host $_.Name '('$_.Confidence')'

                $tag = New-Object Amazon.S3.Model.Tag
                $tag.Key = $_.Name
                $tag.Value = $_.Confidence.ToString()
                $tags += $tag
            }

            Write-S3ObjectTagSet -BucketName $bucket -Key $key -Tagging_TagSet $tags
        } else {
            $inputFileName = [System.IO.Path]::GetFileName($key)
            $outputFileName = [System.IO.Path]::Combine($outputFilePrefix, $inputFileName + '.keywords')

            Write-Host "Writing $($labels.Count) labels for image $key to $outputFileName"

            $keywords = @()
            $labels | ForEach-Object {

                $keywords += @{
                    'Keyword'=$_.Name
                    'Confidence'=$_.Confidence
                }
            }

            Write-S3Object -BucketName $bucket -Key $outputFileName -Content (ConvertTo-Json -InputObject $keywords)
        }
    } else {
        Write-Host "Skipped processing: object does not match a known image extension ($imageExtensions -join ',')"
    }
}

