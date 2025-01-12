"""
Python URI Shortener
"""
import hashlib
import uuid
import boto3

# Initialize DynamoDB
region_name = 'us-east-1'
dynamoDB = boto3.resource('dynamodb', region_name=region_name)
table = dynamoDB.Table('uri-table')

def generate_short_url(long_url):
    """
    Generate a short URL based on the MD5 hash of the long URL.
    """
    hash_object = hashlib.md5(long_url.encode())
    hash_digest = hash_object.hexdigest()
    short_uri = hash_digest[:5]
    base_url = "http://short_url/"  # Replace with your actual domain name
    return f"{base_url}{short_uri}"

def save_to_dynamodb(original_url, short_url):
    """
    Save the generated short URL to the DynamoDB table.
    """
    try:
        table.put_item(
            Item={
                'Id': str(uuid.uuid4()),  # Unique ID for the entry
                'shorten-uri': short_url,
                'original-url': original_url  # Match table schema
            }
        )
        print(f"Successfully updated table with short URL: {short_url}")
    except Exception as e:
        print(f"Error updating table: {e}")

def main():
    """
    Main function to handle input, URL shortening, and saving to DynamoDB.
    """
    try:
        # Get URL input from the user
        input_url = input("Enter the URL to shorten: ").strip()
        if not input_url:
            raise ValueError("No URL provided. Please run the script again.")

        # Generate short URL
        short_url = generate_short_url(input_url)
        print(f"Shortened URL: {short_url}")

        # Save short URL to DynamoDB
        save_to_dynamodb(input_url, short_url)

    except ValueError as ve:
        print(ve)
    except EOFError:
        print("No input provided. Please run the script again.")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
