FROM python:3.12.4-alpine

WORKDIR /app

COPY . /app

ENV FLASK_APP=main

RUN pip3 install -r requirements.txt

CMD ["flask", "run", "--host=0.0.0.0"]