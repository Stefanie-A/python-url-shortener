"""
Python URI shortener
"""
import hashlib
import uuid
import boto3

# Initialize DynamoDB
region_name = 'us-east-1'
dynamoDB = boto3.resource('dynamodb', region_name=region_name)
table = dynamoDB.Table('newURI')

def generate_short_url(long_url):
    """
    Generate a short URL based on the MD5 hash of the long URL.
    """
    hash_object = hashlib.md5(long_url.encode())
    hash_digest = hash_object.hexdigest()
    short_url = hash_digest[:5]
    base_url = "http://short_url/"  # Replace with your actual domain name
    return f"{base_url}{short_url}"

def update_table(table, short_url):
    """
    Update the DynamoDB table with the generated short URL.
    """
    try:
        table.put_item(
            Item={
                'id': str(uuid.uuid4()),
                'shorturl': short_url
            }
        )
        print(f"Successfully updated table with short URL: {short_url}")
    except Exception as e:
        print(f"Error updating table: {e}")

if __name__ == "__main__":
    try:
        # Get URL input from the user
        input_url = input("Enter the URL to shorten: ")
        
        # Generate short URL
        SHORT_URI = generate_short_url(input_url)
        print(f"Shortened URL: {SHORT_URI}")
        
        # Update DynamoDB table
        update_table(table, SHORT_URI)
        
    except EOFError:
        print("No input provided. Please run the script again.")
    except Exception as e:
        print(f"Error: {e}")
