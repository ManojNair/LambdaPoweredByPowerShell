#==============================================================================
# Query parameters to customize this function:
#  feed (required)      The url of the RSS feed to obtain blog posts from.
#  maxPosts             The maximum number of posts to convert to speech. Defaults
#                       to 1 if not specified.
#  voiceId              Speech conversion voice. Defaults to 'Nicole' if not
#                       specified.
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
#Requires -Modules AWS.Tools.Common,AWS.Tools.Polly,AWS.Tools.S3,AWS.Tools.SimpleNotificationService,AWS.Tools.SimpleSystemsManagement

$feed = $LambdaInput.queryStringParameters.feed
if (!($feed)) {
    $feed = 'http://feeds.feedburner.com/AmazonWebServicesBlog'
}

$maxPosts = $LambdaInput.queryStringParameters.maxPosts
if (!($maxPosts)) {
    $maxPosts = 1
}
$voiceId = $LambdaInput.queryStringParameters.voiceId
if (!($voiceId)) {
    $voiceId = 'Nicole'
}

$outputBucket = (Get-SSMParameterValue -Name '/RSS2Speech/OutputBucket').Parameters[0].Value
$notificationTopic = (Get-SSMParameterValue -Name '/RSS2Speech/NotificationTopicArn').Parameters[0].Value

$feedUrl = "$feed`?fmt=xml"
Write-Host "Processing feed $feedUrl to return latest $maxPosts item(s) into bucket $outputBucket using voice $voiceId"
$doc = Invoke-RestMethod -Uri $feedUrl

$blogsOutput = 0
$tempPath = [System.IO.Path]::GetTempPath()

$responseBody = ""

while ($blogsOutput -lt $maxPosts) {
    $text = $doc[$blogsOutput].description
    $speech = Get-POLSpeech -VoiceId $voiceId -Text $text -OutputFormat mp3

    $tempFilename = [System.IO.Path]::GetRandomFileName()
    $tempFile = [System.IO.Path]::Combine($tempPath, $tempFilename)

    $fs = [System.IO.FileStream]::new($tempFile, [System.IO.FileMode]::CreateNew)
    $speech.AudioStream.CopyTo($fs)
    $fs.Close()

    $title = $doc[$blogsOutput].title
    $key = "$title.mp3"
    Write-S3Object -BucketName $outputBucket -Key $key -File $tempFile -ContentType "audio/mpeg"

    $presignedUrlArgs = @{
        BucketName = $outputBucket
        Key = $key
        Expire = ([DateTime]::Now).AddDays(7)
        Verb = 'GET'
        Protocol = 'HTTPS'
        ResponseHeaderOverrides_ContentType = 'audio/mpeg'
    }
    $mp3Url = Get-S3PreSignedURL @presignedUrlArgs

    $publishArgs = @{
        TopicArn = $notificationTopic
        Subject = "Blog post - $title"
        Message = "Blog $title is now available at $mp3Url"
    }
    Publish-SNSMessage @publishArgs

    $responseBody += "$title - $mp3Url`n"

    $blogsOutput += 1
    if ($doc.Length -le $blogsOutput) {
        break;
    }
}

# Output response to Api Gateway
@{
    'statusCode' = 200;
    'body' = $responseBody;
    'headers' = @{'Content-Type' = 'text/plain'}
}
