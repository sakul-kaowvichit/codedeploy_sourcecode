import boto3
import paramiko


def worker_handler(event, context):

    s3_client = boto3.client('s3')
    #Download private key file from secure S3 bucket
    s3_client.download_file('pp-deployment','key/codedeploy.pem', '/tmp/codedeploy.pem')

    k = paramiko.RSAKey.from_private_key_file("/tmp/codedeploy.pem")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    host=event['IP']
    print "Connecting to " + host
    c.connect( hostname = host, username = "ubuntu", pkey = k )
    print "Connected to " + host

    commands = [
        "aws s3 cp s3://pp-deployment/lambda/brain/stop_worker_queue.sh /home/ubuntu",
        "chmod 700 /home/ubuntu/stop_worker_queue.sh",
        "/home/ubuntu/stop_worker_queue.sh"
        ]
    for command in commands:
        print "Executing {}".format(command)
        stdin , stdout, stderr = c.exec_command(command)
        print stdout.read()
        print stderr.read()

    err=stderr.read()
    if err:
        message="ERROR:\n{0}".format(err)
    else:
        out=stdout.read()
        message="INFO:\n{0}".format(out)
    return
    {
        'message' : message
    }


