"""
API to get all urls

"""
from main import table
from fastapi import FastAPI

app = FastAPI()

@app.get("/url")
def get_url():
    response = table.scan()
    data = response['Items']
    return {
        data
    }
