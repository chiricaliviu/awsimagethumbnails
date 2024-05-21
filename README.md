Started the project by following AWS Guide on creating thumnails.
Images that have been uploaded to the input bucket are proccesed by the lambda function. 
The function is triggered by the insert event and it will process the image and it will save them in the output bucket.
The project contains the terraform main file and the lambda function declaration.

In terms of AWS Services the following services were provisioned:

    S3 bucket as an input directory
    S3 bucket as an output directory
    AWS role
    AWS aws policy
    AWS lambda function



