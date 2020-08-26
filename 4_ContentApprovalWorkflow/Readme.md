# Content Approval Workflow Demo

This demo illustrated using PowerShell-based Lambda functions in an [Amazon Step Functions](https://aws.amazon.com/step-functions) workflow, to simulate a content approval system (for example, a user wanting to send a tweet must first send it for approval). The approval workflow consists of automated and manual steps. The manual step can take an indeterminate period of time (a human must perform the final approve/reject step on the content) so the workflow uses a continuation token and pauses while waiting for the final human approval, which is done by clicking generated links in an email. Once the user clicks the appropriate link the workflow 'wakes up' and performs the final task in the workflow to notify the original submitter of the decision.

The demo also illustrates invoking another Lambda function from within a Lambda - in this case to obtain the callback urls to place into the approve/reject email. This is done using the [sfn-callback-urls](https://serverlessrepo.aws.amazon.com/applications/arn:aws:serverlessrepo:us-east-2:866918431004:applications~sfn-callback-urls) serverless application available from the [AWS Serverless Application Repository](https://serverlessrepo.aws.amazon.com/applications) to generate the approve/reject urls containing the continuation token.

For this sample to work you must first deploy the *sfn-callback-urls* application to your account. When that completes, make a note of the ARN of the callback function (it will have a name similar to serverlessrepo-sfn-callback-urls-CreateUrls-**RANDOM**).

To deploy the sample, run the .\build_and_deploy.ps1 script and provide the following parameters:

- CallbackUrlsFunctionArn - the ARN of the callback function that you recorded after deploying the *sfn-callback-urls* app to your account
- ApproverEmail - the email of the user who will receive the generated email asking them to approve/reject the submitted content
- UnapprovedWords - (optional) - comma-separated list of words that if found in the content, will cause the request to be automatically rejected

Once the sample is deployed, open the email of the user and confirm the SNS subscription. Then, go to the Step Functions console and execute the deployed state machine, passing the following payload (edit to suit!)

```json
{
  "requester": "Steve",
  "content": "This is an awesome demo, if it works!"
}
```

You will see the state machine execute the automated approval check (which will cause rejection if any 'unapproved' words are found in the Content), check for content to redact, then generate an email including accept/reject links which will be sent to the user. The state machine will pause execution at this point.

Once the appropriate link in the email is clicked the state machine workflow will resume and send a confirmation receipt email to the approver of their approve/reject decision, or rejection due to automated checks, before concluding (it is assumed the requester is notified of the decision by either another yet-to-be-written Lambda function).
