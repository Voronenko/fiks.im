check-key-match:
	echo "fiksim"
	openssl rsa -noout -modulus -in fiksim_privkey.pem | openssl md5
	openssl x509 -noout -modulus -in fiksim_cert.pem | openssl md5
	echo "rsa"
	openssl rsa -noout -modulus -in rsa_fiksim_privkey.pem | openssl md5
	openssl x509 -noout -modulus -in rsa_fiksim_cert.pem | openssl md5

check-cert-dates:
	echo "fiksim"
	openssl x509 -in fiksim_cert.pem -noout -dates
	echo "rsa"
	openssl x509 -in rsa_fiksim_cert.pem -noout -dates

check-cert-details:
	echo "fiksim"
	openssl x509 -in fiksim_cert.pem -text -noout
	echo "rsa"
	openssl x509 -in rsa_fiksim_cert.pem -text -noout

check-fullchain-contains-entire-chain:
	echo "fiksim"
	openssl crl2pkcs7 -nocrl -certfile fiksim_fullchain.pem | openssl pkcs7 -print_certs -text -noout
	echo "rsa"
	openssl crl2pkcs7 -nocrl -certfile rsa_fiksim_fullchain.pem | openssl pkcs7 -print_certs -text -noou

validate-trust:
	echo "fiksim"
	openssl verify -CAfile fiksim_fullchain.pem cert.pem
	echo "rsa"
	openssl verify -CAfile rsa_fiksim_fullchain.pem cert.pem

