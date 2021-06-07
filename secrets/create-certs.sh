#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose \
    -o xtrace

CA_KEY_PASS='cakeypass'
CLIENT_KEY_PASS='clientkeypass'
# Generate CA key
openssl req -new -x509 -keyout local-ca-1.key -out local-ca-1.crt -days 3650 -subj '/CN=ca1.dev.kopparam.com/OU=Kashyap/O=Acme Inc./L=Geylang/ST=Singapore/C=SG' -passin pass:$CA_KEY_PASS -passout pass:$CA_KEY_PASS
# openssl req -new -x509 -keyout local-ca-2.key -out local-ca-2.crt -days 3650 -subj '/CN=ca2.dev.kopparam.com/OU=Kashyap/O=Acme Inc./L=Geylang/ST=Singapore/C=SG' -passin pass:confluent -passout pass:confluent

# Client keys
openssl genrsa -aes128 -passout "pass:$CLIENT_KEY_PASS" -out kafka.client.key 2048
openssl req -passin "pass:$CLIENT_KEY_PASS" -key kafka.client.key -new -out kafka.client.req -subj '/CN=kafka.client.dev.kopparam.com/OU=Kashyap/O=Acme Inc./L=Geylang/ST=Singapore/C=SG'
openssl x509 -req -CA local-ca-1.crt -CAkey local-ca-1.key -in kafka.client.req -out kafka-ca1-signed.pem -days 9999 -CAcreateserial -passin "pass:$CA_KEY_PASS"


for i in broker1 producer consumer
do
	echo $i
	KEYSTORE_PASS="${i}keystorepass"
	TRUSTSTORE_PASS="${i}truststorepass"
	# Create keystores
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=localhost, OU=CEO, O=Acme Inc., L=Geylang, ST=Singapore, C=SG" \
				 -keystore kafka.$i.keystore.jks \
				 -keyalg RSA \
				 -storepass $KEYSTORE_PASS \
				 -keypass $KEYSTORE_PASS

	# Create CSR, sign the key and import back into keystore
	keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass $KEYSTORE_PASS -keypass $KEYSTORE_PASS

	openssl x509 -req -CA local-ca-1.crt -CAkey local-ca-1.key -in $i.csr -out $i-ca1-signed.crt -days 9999 -CAcreateserial -passin pass:$CA_KEY_PASS

	keytool -keystore kafka.$i.keystore.jks -alias CARoot -import -file local-ca-1.crt -storepass $KEYSTORE_PASS -keypass $KEYSTORE_PASS

	keytool -keystore kafka.$i.keystore.jks -alias $i -import -file $i-ca1-signed.crt -storepass $KEYSTORE_PASS -keypass $KEYSTORE_PASS

	# Create truststore and import the CA cert.
	keytool -keystore kafka.$i.truststore.jks -alias CARoot -import -file local-ca-1.crt -storepass $TRUSTSTORE_PASS -keypass $TRUSTSTORE_PASS

  echo "$KEYSTORE_PASS" > ${i}_sslkey_creds
  echo "$KEYSTORE_PASS" > ${i}_keystore_creds
  echo "$TRUSTSTORE_PASS" > ${i}_truststore_creds
done
