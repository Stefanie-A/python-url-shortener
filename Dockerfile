FROM python:3.12-slim AS build1

WORKDIR /app

COPY ./app/requirements.txt .

RUN pip install -r requirements.txt

COPY ./app/main.py .

CMD ["python", "main.py"]


FROM build1 As build2

COPY ./app/requirements.txt .

RUN pip install -r requirements.txt

COPY ./app/api.py .

CMD ["uvicorn", "main.py", "--reload"]

