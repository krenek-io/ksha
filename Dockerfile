FROM amazon/aws-cli

RUN yum install -y jq

COPY . /app

WORKDIR /app

ENTRYPOINT ["/app/controller.sh"]
