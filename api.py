"""
API to get all urls

"""
from fastapi import FastAPI
from main import table

app = FastAPI()

@app.get("/url")
def get_url():
    response = table.scan()
    data = response['Items']
    return {
        data
    }
