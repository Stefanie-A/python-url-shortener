FROM python:3.12-slim

WORKDIR /app

copy requirements.txt .

RUN pip install -r requirements.txt

COPY . .

CMD ["python", "main.py"]

