FROM python:3.12-slim AS build1

WORKDIR /app

COPY ./infrastructure/app/requirements.txt .

RUN pip install -r ./infrastructure/app/requirements.txt

COPY ./infrastructure/app/main.py .

CMD ["python", "main.py"]


FROM build1 As build2

COPY ./infrastructure/app/requirements.txt .

RUN pip install -r requirements.txt

COPY ./infrastructure/app/api.py .

CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--reload"]