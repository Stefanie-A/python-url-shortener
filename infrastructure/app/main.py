from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, HttpUrl
import hashlib
import uuid
import boto3
import mangum

app = FastAPI()

region_name = 'us-east-1'
dynamoDB = boto3.resource('dynamodb', region_name=region_name)
table = dynamoDB.Table('url-table')

class URLRequest(BaseModel):
    url: HttpUrl

def generate_short_url(long_url):
    hash_object = hashlib.md5(long_url.encode())
    hash_digest = hash_object.hexdigest()
    short_uri = hash_digest[:5]
    base_url = "http://short_url/"  # Replace with your actual domain name
    return f"{base_url}{short_uri}"

def save_to_dynamodb(original_url, short_url):
    try:
        table.put_item(
            Item={
                'Id': str(uuid.uuid4()),
                'shorten-uri': short_url,
                'original-url': original_url
            }
        )
    except Exception as e:
        raise Exception(f"Error updating table: {e}")

@app.post("/shorten")
def shorten_url(request: URLRequest):
    input_url = request.url.strip()
    if not input_url:
        raise HTTPException(status_code=400, detail="No URL provided.")
    short_url = generate_short_url(input_url)
    try:
        save_to_dynamodb(input_url, short_url)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"shortened_url": short_url}

handler = mangum.Mangum(app)