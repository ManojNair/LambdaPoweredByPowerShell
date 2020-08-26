# ImageTagger Demo

This demo illustrated having a Lambda function be invoked as a result of an event, in this case when a new object is created, or an existing object updated, in an [Amazon S3](https://aws.amazon.com/s3/) bucket. It also illustrates two options for deployment - using the AWSLambdaPSCore tools, or creating and deploying a serverless template using the [AWS Lambda extensions for the dotnet CLI](https://github.com/aws/aws-extensions-for-dotnet-cli).

The sample Lambda function uses [Amazon Rekognition](https://aws.amazon.com/rekognition/) to inspect uploaded image files to 'keyword' it (Rekognition uses the term 'label'). The detected labels can be applied to the S3 object as tags (the default, which will attach up to 10 tags) or the function can be configured using environment variables to write the labels to a file in the same S3 bucket (but different key prefix to prevent a runaway set of Lambda invocations!). When writing to a file all detected labels are output (see the function code for more details).

My usage scenario for this function is as a photographer outside of AWS, I submit images to various online galleries that all require images to be tagged regarding the content. Thinking up tags is tedious and can be time consuming with a lot of images! Therefore I have a personal project to write an extension for Adobe Lightroom, which I use, to automate the process of getting a baseline set of tags for images which will make use of this function.

To build and deploy using the AWSLambdaPSCore tools see the [deploy_with_awslambdapscore.ps1](./deploy_with_awslambdapscore.ps1) script. When choosing this option you need to do some manual post-deployment configuration to setup an S3 bucket as an event source - see the comments at the top of the script.

To build the deployment package with the AWSLambdaPSCore tools and deploy using the dotnet CLI see the [deploy_with_dotnetcli.ps1](./deploy_with_dotnetcli.ps1) script. The [AWS CloudFormation](https://aws.amazon.com/cloudformation/) template (./serverless.template) used in this step also creates and configures an S3 bucket to act as an event source so you do not need to perform the post-deployment configuration step.