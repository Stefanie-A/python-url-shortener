FROM python:3.12-slim AS build

WORKDIR /app

COPY . .

CMD ["python", "main.py"]


FROM builder As build1

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY api.py .

CMD ["uvicorn", "main.py", "--reload"]

