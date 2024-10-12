FROM python:3.12-slim AS build1

WORKDIR /app

COPY . .

CMD ["python", "main.py"]


FROM build1 As build2

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY api.py .

CMD ["uvicorn", "main.py", "--reload"]

