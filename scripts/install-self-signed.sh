export SWIRL_FQDN="updswirl440-441-2.swirl-metasearch.com"
export INSTALLATION_DIR="/app"
export SSL_DIR="${INSTALLATION_DIR}/nginx/certificates/ssl/${SWIRL_FQDN}"

mkdir -p "${SSL_DIR}"

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "${SSL_DIR}/ssl_certificate_key.key" \
  -out "${SSL_DIR}/ssl_certificate.crt" \
  -subj "/CN=${SWIRL_FQDN}" \
  -addext "subjectAltName=DNS:${SWIRL_FQDN}"

chmod 600 "${SSL_DIR}/ssl_certificate_key.key"
chmod 644 "${SSL_DIR}/ssl_certificate.crt"

openssl x509 -in "${SSL_DIR}/ssl_certificate.crt" -noout -subject -issuer -dates
echo "----"
openssl x509 -in "${SSL_DIR}/ssl_certificate.crt" -noout -ext subjectAltName

openssl x509 -in "${SSL_DIR}/ssl_certificate.crt" -noout -text | egrep "Subject:|DNS:${SWIRL_FQDN}|Not Before|Not After"
