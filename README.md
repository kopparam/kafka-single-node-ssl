### Run a Kafka single node cluster with Docker locally


## Run
Simply run the docker-compose.yml with `docker-compose up`

This will start the Kafka broker on port 19093

## Regenerate the keys

1. Delete everything but `create-certs.sh` from `/secrets`
1. Run `create-certs.sh`

## Connect to Kafka using SSL
1. `kafka-console-consumer.sh --bootstrap-server localhost:19093 --topic test --consumer.config client-ssl.properties --from-beginning`
