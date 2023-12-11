FROM python:3.7
COPY templates ./templates
COPY mysqloperator.py ./mysqloperator.py
RUN pip install kopf kubernetes pyyaml jinja2
CMD kopf run ./mysqloperator.py
