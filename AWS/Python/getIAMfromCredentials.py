# Gets the IAM user id from a set of credentials
# Usage:
# getIAMfromCredentials.py *AWS ID* *AWS SECRET*

import boto3, sys

aws_id = sys.argv[1]
aws_secret = sys.argv[2]

print("AWS ID: " + aws_id)
print("AWS Secret: " + aws_secret)

client = boto3.client("sts", aws_access_key_id=aws_id, aws_secret_access_key=aws_secret)
account_id = client.get_caller_identity()["Account"]
account_arn = client.get_caller_identity()["Arn"]

print("ID: " + account_id)
print("Arn: " + account_arn)