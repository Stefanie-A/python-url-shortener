"""
API to get all urls

"""
from fastapi import FastAPI
from main import table

app = FastAPI()

@app.get("/")
def home():
    return {
        "Welcome!"
    }
@app.get("/urls")
def get_url():
    try:
        response = table.scan()
        data = response['Items']
        return {
            "urls": data
        }
    except Exception as e:
        return {
            "error": str(e)
        }
