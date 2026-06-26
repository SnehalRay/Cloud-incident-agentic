FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY agent ./agent

# Default to a full diagnosis run; override the command to ask a specific question.
ENTRYPOINT ["python", "-m", "agent"]
