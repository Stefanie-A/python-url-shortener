""" 
Python URI shortener
"""
import hashlib
import uuid
import boto3

region_name = 'us-east-1'
dynamoDB = boto3.resource('dynamodb', region_name=region_name)
table = dynamoDB.Table('newURI')

def generate_short_url(long_url):
    """
    URI function

    """
    hash_object = hashlib.md5(long_url.encode())
    hash_digest = hash_object.hexdigest()
    short_url = hash_digest[:5]
    base_url = "http://short_url/" #replace with your domain name
    return f"{base_url}{short_url}"

def update_table(table):
    table.put_item(
            Item={
                'id': str(uuid.uuid()),
                'shorturl' : SHORT_URI
                }
        )

try:
    update_table(table)
except Exception as e:
    print(f"Error updating table: {e}")


if __name__ == "__main__":
    try:
        input_url = input("Enter the URL to shorten: ")
        SHORT_URI = generate_short_url(input_url)
        print(f"Shortened URL: {SHORT_URI}")
    except EOFError:
        print("No input provided. Please run the script again.")
    except Exception as e:
        print(f"Error: {e}")