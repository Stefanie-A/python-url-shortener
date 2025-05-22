FROM python:3.12-slim

WORKDIR /app

COPY infrastructure/app/requirements.txt .

RUN pip install -r requirements.txt

COPY infrastructure/app/main.py .

CMD ["uvicorn", "main.py", "--host", "0.0.0.0", "--port", "80", "--reload"]