import boto3

code_pipeline = boto3.client('codepipeline')


def put_job_failure(job, message):
    print('Putting job failure')
    print(message)
    code_pipeline.put_job_failure_result(jobId=job, failureDetails={'message': message, 'type': 'JobFailed'})
 

def put_job_success(job, message):
    print('Putting job success')
    print(message)
    code_pipeline.put_job_success_result(jobId=job)


def trigger_handler(event, context):
    job_id = event['CodePipeline.job']['id']

    #Get IP addresses of EC2 instances
    client = boto3.client('ec2')
    instDict=client.describe_instances(
            Filters=[{'Name':'tag:Name','Values':['stage_brain']}]
        )

    hostList=[]
    for r in instDict['Reservations']:
        for inst in r['Instances']:
            hostList.append(inst['PublicIpAddress'])

    #Invoke worker function for each IP address
    client = boto3.client('lambda')
    for host in hostList:
        print "Invoking worker_function on " + host
        invokeResponse=client.invoke(
            FunctionName='worker_function',
            InvocationType='Event',
            LogType='Tail',
            Payload='{"IP":"'+ host +'"}'
        )
        print invokeResponse

    put_job_success(job_id, 'done kicking off lambda workers')

    return{
        'message' : "Trigger function finished"
    }

