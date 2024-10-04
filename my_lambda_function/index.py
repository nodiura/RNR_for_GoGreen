def handler(event, context):
    """
    A simple AWS Lambda function that returns a greeting.
    """
    name = event.get("queryStringParameters", {}).get("name", "from GoGreen")
    message = f"Hello, {name}!"
    
    return {
        "statusCode": 200,
        "body": message
    }