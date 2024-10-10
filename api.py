from main import *
from fastapi import FastAPI

app = FastAPI()

@app.get("/url")
def get_url():
    response = table.scan()
    data = response['Items']
    return {
        data
    }