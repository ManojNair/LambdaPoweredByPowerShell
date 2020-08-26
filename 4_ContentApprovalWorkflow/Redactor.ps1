#==============================================================================
# Using Amazon Comprehend, this function inspects the supplied content for
# to first detect the language and then removes all proper nouns and nouns from
# content, replacing each word with an array of a solid block unicode characters
# numbering the same as the the length of the word.
#
# Input to this function:
#   PSObject with 'requester' and 'content' fields.
#
# Environment parameters to customize this function:
#   none
#
#=============================================================================

# When executing in Lambda the following variables will be predefined.
#   $LambdaInput - A PSObject that contains the Lambda function input data.
#   $LambdaContext - An Amazon.Lambda.Core.ILambdaContext object that contains information about the currently running Lambda environment.
#
# The last item in the PowerShell pipeline will be returned as the result of the Lambda function.

#Requires -Modules AWS.Tools.Common,AWS.Tools.Comprehend

$content = $LambdaInput.content

$lang = Find-COMPDominantLanguage -Text $content
Write-Host "Dominant language determined to be $lang"

$syntax = Find-COMPSyntax -Text $content -LanguageCode $lang.LanguageCode
$words = $syntax |
    Where-Object {
    $_.PartOfSpeech.Tag -eq "PROPN" -or
    $_.PartOfSpeech.Tag -eq "NOUN"
}

foreach ($word in $words) {
    $chars = ($word.EndOffset - $word.BeginOffset)
    $content = $content.Remove($word.BeginOffset, $chars)
    $filler = "`u{2588}" * $chars
    $content = $content.Insert($word.BeginOffset, $filler)
}

$LambdaInput.content = $content

$LambdaInput
