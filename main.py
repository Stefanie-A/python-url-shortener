""" 
Python URI shortener
"""
import hashlib
import boto3

dynamoDB = boto3.resource('dynamodb')
table = dynamoDB.Table('newURI')

input_url = input("Enter the URL to shorten: ")

def url_shortener(long_url):
    """
    URI function

    """
    hash_object = hashlib.md5(long_url.encode())
    hash_digest = hash_object.hexdigest()
    short_url = hash_digest[:5]
    base_url = "http://short_url/" #replace with your domain name
    return f"{base_url}{short_url}"


SHORT_URI = url_shortener(input_url)

if __name__ == "__main__":
    print(f"Shortened URL: {SHORT_URI}" )


def update_table(table):
    table.put_item(
            Item={
                'id': '1',
                'shorturl' : SHORT_URI
                }
        )
